# == Definition: reprepro::lib::overrides_cron
#
# Adds cron job to update overrides for a "Distribution".
#
# === Parameters
#
#   - *repository*: the name of the distribution (required)
#   - *codename*:   distro release codename (defaults to $name)
#   - *ensure*:     present/absent, defaults to present
#   - *hours*:      Hours during which to run cron job. Minutes are psuedo-random
#   - *repo_owner*: Owner of cron job
#
# === Requires
#
#   - Class["reprepro"]
#
# === Example
#
#   reprepro::lib::overrides_cron { "xenial":
#     repository    => "pulse",
#     ensure        => present,
      
#   }
#
#
define reprepro::lib::overrides_cron (
  $repository,
  $codename   = "${name}",
  $ensure     = present,
  $hours      = [ '01', '18', ],
  $repo_owner = $::reprepro::user_name,
){

  if is_string( $ensure ) {
    validate_re( $ensure, [ '^present$', '^absent$', '^true$', '^false$', ] )
    $_ensure = $ensure ? {
      'present' => 'present',
      'true'    => 'present',
      default   => 'absent',
    }
  }
  else {
    validate_bool( $ensure )
    $_ensure = $ensure ? {
      true    => 'present',
      default => 'absent',
    }
  }
  
  $homedir = "${::reprepro::homedir}/${repository}"
  
  validate_integer( $hours, 24, 0 )
  if is_string( $hours ) {
    $_hours = unique( any2array( $hours ) )
  }
  else {
    $_hours = unique( $hours )
  }
  
  cron { "${repository}_${codename}_update_overrides":
    ensure      => $ensure,
    command     => "${homedir}/indices/update-indices ${codename}",
    user        => $repo_owner,
    environment => 'SHELL=/bin/bash',
    minute      => fqdn_rand( 60, "${repo}_${codename}_update_overrides"),
    hour        => $_hours,
    require     => File["${homedir}/indices/update-indices"],
    notify  => Exec[ "${repository}_${codename}_init_overrides" ],
  }
  
  exec { "${repository}_${codename}_init_overrides":
    path        => '/usr/bin:/bin',
    cwd         => "${homedir}/indices",
    user        => "${repo_owner}",
    command     => "${homedir}/indices/update-indices ${codename}",
    refreshonly => true,
    require     => File[ "${homedir}/indices/update-indices" ],
  }      

}