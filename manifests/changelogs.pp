# == Definition: reprepro::changelogs
#
# Adds a "changelogs" to manage.
#
# === Parameters
#
#   - *ensure* present/absent, defaults to present
#   - *basedir* reprepro basedir
#   - *repository*: the name of the changelog
#
# === Requires
#
#   - Class["reprepro"]
#
# === Example
#
#   reprepro::changelogs {"lenny":
#     ensure        => present,
#     repository    => "my-repository",
#   }
#
#
define reprepro::changelogs (
  $codename   = $name,
  $repository,
  $ensure     = 'simple',
  $basedir    = $::reprepro::basedir,
  $homedir    = $::reprepro::homedir,
  $owner      = "${::reprepro::user_name}",
) {

  if ! is_bool( $ensure ) {
    validate_re( $ensure, [ '^present$', '^absent$', '^simple$', '^full$'] )
  }
  
  $source_dir = '/usr/share/doc/reprepro/examples'
  $target_dir = "${basedir}/${repository}/conf"
  
  case $ensure {
    false, 'absent': {
      file { "${target_dir}/changelogs.${codename}":
        ensure => absent,
      }
    }
    default: {
      exec { "${name}_install_changelogs_script":
        path    => '/usr/bin:/bin',
        user    => "${owner}",
        command => "test -f ${source_dir}/changelogs.example.gz && gunzip -c ${source_dir}/changelogs.example.gz > ${target_dir}/changelogs.${codename} || { [ -f ${source_dir}/changelogs.example ] && cp ${source_dir}/changelogs.example ${target_dir}/changelogs.${codename}; } && chmod ug+x ${target_dir}/changelogs.${codename}",
        creates => "${target_dir}/changelogs.${codename}",
        require => File[ "${basedir}/${repository}/conf" ],
      }
      file_line { "${name}_changelogs_mode":
        ensure  => present,
        path    => "${target_dir}/changelogs.${codename}",
        line    => $ensure ? { 
          'full'  => "CHANGELOGDIR=changelogs",
          default => "CHANGELOGDIR=",
        },
        match   => '^CHANGELOGDIR=*',
        require => Exec[ "${name}_install_changelogs_script" ],
      }
    }
  }
}
