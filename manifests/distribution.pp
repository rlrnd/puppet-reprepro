# == Definition: reprepro::distribution
#
# Adds a "Distribution" to manage.
#
# === Parameters
#
#   - *ensure* present/absent, defaults to present
#   - *basedir* reprepro basedir
#   - *repository*: the name of the distribution
#   - *origin*: package origin
#   - *label*: package label
#   - *suite*: package suite
#   - *architectures*: available architectures
#   - *components*: available components
#   - *description*: a short description
#   - *sign_with*: email of the gpg key
#   - *deb_indices*: file name and compression
#   - *dsc_indices*: file name and compression
#   - *update*: update policy name
#   - *pull*: pull policy name
#   - *uploaders*: who is allowed to upload packages
#   - *snapshots*: create a reprepro snapshot on each update
#   - *install_cron*: install cron job to automatically include new packages
#   - *not_automatic*: automatic pined to 1 by using NotAutomatic,
#                      value are "yes" or "no"
#   - *but_automatic_upgrades*: set ButAutomaticUpgrades,
#                      value are "yes" or "no"
#
# === Requires
#
#   - Class["reprepro"]
#
# === Example
#
#   reprepro::distribution {"lenny":
#     ensure        => present,
#     repository    => "my-repository",
#     origin        => "Camptocamp",
#     label         => "Camptocamp",
#     suite         => "stable",
#     architectures => "i386 amd64 source",
#     components    => "main contrib non-free",
#     description   => "A simple example of repository distribution",
#     sign_with     => "packages@camptocamp.com",
#   }
#
#
define reprepro::distribution (
  $repository,
  $architectures,
  $components,
  $origin                 = undef,
  $label                  = undef,
  $suite                  = undef,
  $description            = undef,
  $sign_with              = '',
  $codename               = $name,
  $ensure                 = present,
  $basedir                = $::reprepro::basedir,
  $homedir                = $::reprepro::homedir,
  $fakecomponentprefix    = undef,
  $udebcomponents         = $components,
  $udeb                   = true,
  $changes                = false,
  $disable_overrides      = false,                       #  Disable overrides (if enabled in parent repository)
  $owner                  = $::reprepro::user_name,
  $group                  = $::reprepro::group_name,
  $deb_override           = undef,
  $udeb_override          = undef,
  $dsc_override           = undef,
  $deb_indices            = 'Packages Release .gz .bz2',
  $udeb_indices           = 'Packages .gz .bz2',
  $dsc_indices            = 'Sources Release .gz .bz2',
  $update                 = '',
  $pull                   = '',
  $uploaders              = '',
  $snapshots              = false,
  $install_cron           = true,
  $not_automatic          = '',
  $but_automatic_upgrades = 'no',
  $changelogs             = false,
  $log                    = '',
) {

  include reprepro::params
  
  $repo_homedir = "${homedir}/${repository}"
  
  
  if $disable_overrides {
    $_overrides = false
  }
  else {
    $_overrides = getparam( 'Reprepro::Repository[ "${repository}" ]', 'overrides' )
  }
  
  if ! is_bool( $changelogs ) {
    validate_re( $changelogs, '^simple$', '^full$', )
  }
  
  case $changelogs {
    false, 'absent':   {
      $logscript = ""
    }
    default: {
      $logscript = "changelogs.${codename}"
    }
  }
  reprepro::changelogs { "${codename}":
    ensure     => $changelogs,
    repository => "${repository}",
    basedir    => "${::reprepro::basedir}",
    homedir    => "${::reprepro::homedir}",
    owner      => "${::reprepro::user_name}",
  }
   
  $notify = $ensure ? {
    'present' => Exec["export distribution ${name}"],
    default => undef,
  }
  
  concat::fragment { "distribution-${name}":
    ensure  => $ensure,
    target  => "${basedir}/${repository}/conf/distributions",
    content => template('reprepro/distribution.erb'),
    notify  => $notify,
  }

  exec {"export distribution ${name}":
    command     => "su -c 'reprepro -b ${basedir}/${repository} export ${codename}' ${reprepro::user_name}",
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
    logoutput   => on_failure,
    require     => [
      User[$::reprepro::user_name],
      Reprepro::Repository[$repository]
    ],
  }

  # Configure system for automatically adding packages
  file { "${basedir}/${repository}/tmp/${codename}":
    ensure => directory,
    mode   => '0755',
    owner  => $::reprepro::user_name,
    group  => $::reprepro::group_name,
  }

  if $install_cron {
    if $changes {
      $changes_opt = ' -C'
    }
    if grep( any2array( $architectures ), 'source' ) {
      $src_opt = ' -S'
    }
    if $udeb {
      $udeb_opt = ' -U'
    }
    
    if $snapshots {
      $command = "${homedir}/bin/update-distribution.sh -r ${repository} -c ${codename} -s${changes_opt}${udeb_opt}${src_opt}"
    } else {
      $command = "${homedir}/bin/update-distribution.sh -r ${repository} -c ${codename}${changes_opt}${udeb_opt}${src_opt}"
    }

    cron { "${name} cron":
      command     => $command,
      user        => $owner,
      environment => 'SHELL=/bin/bash',
      minute      => '*/5',
      require     => File["${homedir}/bin/update-distribution.sh"],
    }
  }
  
  
  # Manage dirs and files for overrides
  $idx_dir = "${repo_homedir}/indices"

  if $ensure == present and $_overrides {
    $idx_ensure  = true
    $udeb_ensure = $udeb ? {
      true    => file,
      default => absent,
    }
  }
  else {
    $idx_ensure  = false
    $udeb_ensure = absent
  }
  
  if grep( any2array( $architectures ), 'source' ) {
    $source = true
  }
  else {
    $source = false
  }
  
  if $_overrides {
	  # create update-indices script fragment
	  $deboverride         = "${idx_dir}/override.\${CODENAME}.reprepro"
	  $deb_suffix          = concat( $components, prefix( $components, "extra." ) )  
	  $deb_overrides       = join( prefix( $components, 'override.${CODENAME}.' ), " " )
	  $deb_extra_overrides = join( prefix( $components, 'override.${CODENAME}.extra.' ), " " )
	  
	  if $udeb {
	    $udeboverride   = "${idx_dir}/override.\${CODENAME}.debian-installer.reprepro"
	    $udeb_suffix    = suffix( $components, '.debian-installer' ) 
	    $udeb_overrides = join( prefix( $udeb_suffix, 'override.${CODENAME}.' ), " " )  
	  }
	  else {
	    $udeboverride   = undef
	    $udeb_suffix    = ''
	    $udeb_overrides = undef
	  }
	  if $source {
	    $srcoverride = "${idx_dir}/override.\${CODENAME}.src.reprepro"
	    $src_suffix = suffix( $components, '.src' ) 
	    $src_overrides =  join( prefix( $src_suffix, 'override.${CODENAME}.' ), " " )
	  }
	  else {
	    $srcoverride = undef
	    $src_suffix = ''
	    $src_overrides = undef
	  }
	  
	  $override_suffix = join( unique( delete( concat( $deb_suffix, $udeb_suffix, $src_suffix ), '' ) ), ' ')
	  
	  concat::fragment { "05-update-${repository}-indices-${codename}":
	    content => template( "reprepro/libs/update_indices_distribution.erb" ),
	    target  => "${idx_dir}/update-indices",
	  }
	}
  cron { "${repository}_${codename}_update_overrides":
    ensure      => $idx_ensure ? {
      true    => present,
      default => absent,
    },
    command     => "${idx_dir}/update-indices ${codename}",
    user        => $owner,
    environment => 'SHELL=/bin/bash',
    minute      => fqdn_rand( 60, "${repository}_${codename}_update_overrides"),
    hour        => [ '01', '18', ],
    require     => File["${idx_dir}/update-indices"],
    notify      => Exec[ "${repository}_${codename}_init_overrides" ],
  }
  
  exec { "${repository}_${codename}_init_overrides":
    path        => '/usr/bin:/bin',
    cwd         => "${idx_dir}",
    user        => $owner,
    command     => "${idx_dir}/update-indices ${codename}",
    refreshonly => true,
    require     => File[ "${idx_dir}/update-indices" ],
  }      
	
}
