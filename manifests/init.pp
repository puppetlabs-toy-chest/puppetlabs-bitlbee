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
  $run_mode       = 'Inetd',
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

  case $run_mode {
    'Inetd': {
      xinetd::service { 'bitlbee':
        port         => $bind_port,
        server       => $ssl_cert ? {
          false   => '/usr/sbin/bitlbee',
          default => '/usr/bin/stunnel',
        },
        server_args  => $ssl_cert ? {
          false   => undef
          default => "-p ${ssl_cert} -l /usr/sbin/bitlbee",
        },
        socket_type  => 'stream',
        protocol     => 'tcp',
        user         => 'bittlbee',
        service_type => 'UNLISTED',
        require      => $ssl_cert ? {
          false   => File['bitlbee.conf'],
          default => [ File[[ $ssl_cert, 'bitlbee.conf' ]], Class['stunnel'] ]
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

  file { 'bitlbee.conf':
    path    => '/etc/bitlbee/bitlbee.conf',
    content => template('bitlbee/bitlbee.conf'),
    mode    => '0640',
    owner   => 'root',
    group   => 'bitlbee',
    require => Package['bitlbee'],
  }

}
