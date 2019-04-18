package = 'sonus'
version = 'scm-0'

source = {
  url = 'git://github.com/Mehgugs/sonus.git'
}

description = {
   summary    = 'Adds voice support to novus, powered by telecom.'
  ,homepage   = 'https://github.com/Mehgugs/sonus'
  ,license    = 'MIT'
  ,maintainer = 'Magicks'
  ,detailed   =
[[

]]
}

dependencies = {
   'lua >= 5.3'
  ,'novus'
}

external_dependencies = {
    TELECOM = {
        library = "telecom",
        header = "telecom.h"
    },
    PTHREAD = {
       library = "pthread"
      ,header = "pthread.h"
    }
}

build = {
   type = 'builtin'
  ,modules = {
        ['sonus.core'] = {
           sources = {"src/core.c"}
          ,libraries = {"telecom", "pthread"}
          ,incdirs = {"$(TELECOM_INCDIR)"}
          ,libdirs = {"$(TELECOM_LIBDIR)"}
      }
  }
}