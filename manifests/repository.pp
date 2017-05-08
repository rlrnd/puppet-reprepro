# == Definition: reprepro::repository
#
#   Adds a packages repository.
#
# === Parameters
#
#   - *name*: the name of the repository
#   - *ensure*: present/absent, defaults to present
#   - *basedir*: base directory of reprepro
#   - *incoming_name*: the name of the rule-set, used as argument
#   - *incoming_dir*: the name of the directory to scan for .changes files
#   - *incoming_tmpdir*: directory where the files are copied into
#                        before they are read
#   - *incoming_allow*: allowed distributions
#   - *owner*: owner of reprepro files
#   - *group*: reprepro files group
#   - *options*: reprepro options
#   - *createsymlinks*: create suite symlinks
#
# === Requires
#
#   - Class["reprepro"]
#
# === Example
#
#   reprepro::repository { 'localpkgs':
#     ensure  => present,
#     options => ['verbose', 'basedir .'],
#   }
#
define reprepro::repository (
  $ensure          = present,
  $basedir         = $::reprepro::basedir,
  $homedir         = $::reprepro::homedir,
  $incoming_name   = 'incoming',
  $incoming_dir    = 'incoming',
  $incoming_tmpdir = 'tmp',
  $incoming_allow  = '',
  $overrides       = false,
  $override_src    = 'ca.archive.ubuntu.com',
  $owner           = $::reprepro::user_name,
  $group           = $::reprepro::group_name,
  $options         = ['verbose', 'ask-passphrase', 'basedir .'],
  $createsymlinks  = false,
  ) {

  include reprepro::params
  
  notify { "reprepro_${name}": message => "\noverrides:${overrides}\n" }
  
  $repo_basedir = "${basedir}/${name}"
  $repo_homedir = "${homedir}/${name}"
  
  validate_bool( $overrides )
  
  $dir_ensure = $ensure ? {
    'present' => directory,
    default => absent,
  }
  $opt_ensure = $ensure ? {
    'present' => undef,
    default   => true,
  }
  
  file { "${repo_homedir}":
    ensure  => $dir_ensure,
    purge   => $opt_ensure,
    recurse => $opt_ensure,
    force   => $opt_ensure,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
  }
  
  file { "${repo_basedir}":
    ensure  => $dir_ensure,
    purge   => $opt_ensure,
    recurse => $opt_ensure,
    force   => $opt_ensure,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
  }

  file { "${repo_basedir}/dists":
    ensure  => directory,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
    require => File["${repo_basedir}"],
  }

  file { "${repo_basedir}/pool":
    ensure  => directory,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
    require => File["${repo_basedir}"],
  }

  file { "${repo_basedir}/conf":
    ensure  => directory,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
    require => File["${repo_basedir}"],
  }

  file { "${repo_basedir}/lists":
    ensure  => directory,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
    require => File["${repo_basedir}"],
  }

  file { "${repo_basedir}/db":
    ensure  => directory,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
    require => File["${repo_basedir}"],
  }

  file { "${repo_basedir}/logs":
    ensure  => directory,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
    require => File["${repo_basedir}"],
  }

  file { "${repo_basedir}/tmp":
    ensure  => directory,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
    require => File["${repo_basedir}"],
  }

  file { "${repo_basedir}/incoming":
    ensure  => directory,
    mode    => '2775',
    owner   => $owner,
    group   => $group,
    require => File["${repo_basedir}"],
  }
  
  file { "${repo_basedir}/conf/options":
    ensure  => $ensure,
    mode    => '0640',
    owner   => $owner,
    group   => $group,
    content => inline_template("<%= @options.join(\"\n\") %>\n"),
    require => File["${repo_basedir}/conf"],
  }

  file { "${repo_basedir}/conf/incoming":
    ensure  => $ensure,
    mode    => '0640',
    owner   => $owner,
    group   => $group,
    content => template('reprepro/incoming.erb'),
    require => File["${repo_basedir}/conf"],
  }

  concat { "${repo_basedir}/conf/distributions":
    owner   => $owner,
    group   => $group,
    mode    => '0640',
    require => File["${repo_basedir}/conf"],
  }

  concat::fragment { "00-distributions-${name}":
    ensure  => $ensure,
    content => "# Puppet managed\n",
    target  => "${repo_basedir}/conf/distributions",
  }

  concat { "${repo_basedir}/conf/updates":
    owner   => $owner,
    group   => $group,
    mode    => '0640',
    force   => true, 
    require => File["${repo_basedir}/conf"],
  }

  concat::fragment { "00-update-${name}":
    ensure  => $ensure,
    content => "# Puppet managed\n",
    target  => "${repo_basedir}/conf/updates",
  }

  concat {"${repo_basedir}/conf/pulls":
    owner   => root,
    group   => root,
    mode    => '0644',
    force   => true,
    require => File["${repo_basedir}/conf"],
  }

  concat::fragment { "00-pulls-${name}":
    ensure  => $ensure,
    content => "# Puppet managed\n",
    target  => "${repo_basedir}/conf/pulls",
  }

  if $createsymlinks {
    exec {"${name}-createsymlinks":
      command     => "su -c 'reprepro -b ${repo_basedir} --delete createsymlinks' ${owner}",
      refreshonly => true,
      subscribe   => File["${repo_basedir}/conf/distributions"],
    }
  }
  
  # Overrides
  
  if $overrides {
    $or_ensure = $ensure ? {
      'present' => present,
      default   => absent,
    }
  }
  else {
    $or_ensure = absent
  }
  
  file { "${repo_homedir}/bin":
    ensure  => directory,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
    require => File["${repo_homedir}"],
  }
  
  # Create extraoveride.pl script to add "Task:" information to override.extra.<codename>
  # It requires a copy of the "Packages" file that contains the "Task:" field (e.g. from an install CD)
  # Only required when creating install media as "Task:" is only referenced by
  # preseed files for debian-installer
  ### Note that this script can be installed but is not currently used by any other scripts ###
  #file { "${repo_homedir}/bin/extraoverride.pl":
  #  ensure  => file,
  #  mode    => '0755',
  #  content => template('reprepro/lib/extraoverride.pl.erb'),
  #  require => File["${repo_homedir}/bin"],
  #}
  
  file { "${repo_homedir}/indices":
    ensure  => directory,
    mode    => '2755',
    owner   => $owner,
    group   => $group,
    require => File["${repo_homedir}"],
  }

  concat {"${repo_homedir}/indices/update-indices":
    ensure  => $or_ensure,
    owner   => $owner,
    group   => $group,
    mode    => '0755',
    force   => true,
    require => File["${repo_homedir}/indices"],
  }

  concat::fragment { "00-update-${name}-indices-header":
    content => template( "reprepro/lib/update_indices_header.erb" ),
    target  => "${repo_homedir}/indices/update-indices",
  }
  
  
}
