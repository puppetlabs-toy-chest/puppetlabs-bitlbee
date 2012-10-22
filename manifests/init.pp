# == Class: bitlbee
#
# Full description of class bitlbee here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if it
#   has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should not be used in preference to class parameters  as of
#   Puppet 2.6.)
#
# === Examples
#
#  class { bitlbee:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ]
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2011 Your name here, unless otherwise noted.
#
class bitlbee(
  $run_mode      = 'Inetd',
  $user          = 'bitlbee',
  $bind_address  = '0.0.0.0',
  $bind_port     = '6667',
  $auth_mode     = 'Open',
  $auth_passwd   = false,
  $oper_passwd,
  $hostname      = false,
  $config_dir    = false,
  $ping_interval = false,
  $ping_timeout  = false,
  $ssl_cert      = false,
) {

  if $ssl_cert {
    include stunnel
  }
  if $run_mode == 'Inetd' {
    include xinetd
  }

  # This is most important in configurations that use xinetd...we'll do it
  # just because it doesn't hurt when not using xinetd.
  augeas { 'bitlbee_services':
    context => '/files/etc/services',
    changes => [
      'set service-name[last()+1] bitlbee',
      "set service-name[. = 'bitlbee']/port ${bind_port}",
      'set service-name[. = "bitlbee"]/protocol tcp',
      'set service-name[. = "bitlbee"]#/comment "Bitlbee over SSL"',
    ],
    onlyif  => "match service-name[port = '${bind_port}'][protocol = 'tcp'] size == 0",
    notify  => $run_mode ? {
      'Inetd' => Xinetd::Service['bitlbee'],
      default => Service['bitlbee'],
    },
  }
  augeas { "bitlbee_services_${bind_port}":
    context => '/files/etc/services',
    changes => "set service-name[. = 'bitlbee']/port ${bind_port}",
    onlyif  => "match service-name[port = '${bind_port}'][protocol = 'tcp'] size == 0",
    require => Augeas['bitlbee_services'],
    notify  => $run_mode ? {
      'Inetd' => Xinetd::Service['bitlbee'],
      default => Service['bitlbee'],
    },
  }

  # How we manage a bitlbee server in different situations, xinetd vs. daemon.
  case $run_mode {
    'Inetd': {
      if $ssl_cert {
        file { '/etc/bitlbee/bitlbee.pem':
          source => $ssl_cert,
          mode   => '0600',
          owner  => 'bitlbee',
          group  => 'bitlbee',
          before => Xinetd::Service['bitlbee'],
        }
      }
      xinetd::service { 'bitlbee':
        port         => $bind_port,
        server       => $ssl_cert ? {
          false   => '/usr/sbin/bitlbee',
          default => '/usr/bin/stunnel',
        },
        server_args  => $ssl_cert ? {
          false   => undef,
          default => "-p /etc/bitlbee/bitlbee.pem -l /usr/sbin/bitlbee",
        },
        socket_type  => 'stream',
        protocol     => 'tcp',
        user         => 'bitlbee',
        service_type => 'UNLISTED',
        require      => $ssl_cert ? {
          false   => File['bitlbee.conf'],
          default => [ File['bitlbee.conf' ], Class['stunnel'] ],
        },
      }
    }
    'Daemon','ForkDaemon': {
      service { 'bitlbee':
        ensure  => running,
        enable  => true,
        require => File['bitlbee.con'],
      }
    }
  }

  package { 'bitlbee': ensure => present }

  # The bitlbee config file, kind obvious.
  file { 'bitlbee.conf':
    path    => '/etc/bitlbee/bitlbee.conf',
    content => template('bitlbee/bitlbee.conf.erb'),
    mode    => '0640',
    owner   => 'root',
    group   => 'bitlbee',
    require => Package['bitlbee'],
  }

  # Xinetd doesn't have a status command...yes this should be fixed in its
  # module and not here.
  Service <| title == 'xinetd' |> { hasstatus => false }

  # This is completely unused...just that the stunnel service needs something
  # to load or it never starts.
  stunnel::tun { 'telnet':
    certificate => "/var/lib/puppet/ssl/certs/${::clientcert}.pem",
    private_key => "/var/lib/puppet/ssl/private_keys/${::clientcert}.pem",
    ca_file     => '/var/lib/puppet/ssl/certs/ca.pem',
    crl_file    => '/var/lib/puppet/ssl/crl.pem',
    chroot      => '/var/lib/stunnel4/rsyncd',
    user        => 'puppet',
    group       => 'puppet',
    client      => false,
    accept      => '4423',
    connect     => '23',
    notify      => Service[$stunnel::data::service],
  }
}
