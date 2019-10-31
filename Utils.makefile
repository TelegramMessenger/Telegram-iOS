
export BUCK_DEBUG_OPTIONS=\
	--config custom.other_cflags="-O0 -D DEBUG" \
  	--config custom.other_cxxflags="-O0 -D DEBUG" \
  	--config custom.optimization="-Onone" \
  	--config custom.config_swift_compiler_flags="-DDEBUG"

export BUCK_RELEASE_OPTIONS=\
	--config custom.other_cflags="-Os" \
  	--config custom.other_cxxflags="-Os" \
  	--config custom.optimization="-O" \
  	--config custom.config_swift_compiler_flags="-whole-module-optimization"

export BUCK_THREADS_OPTIONS=--config build.threads=$(shell sysctl -n hw.logicalcpu)

ifneq ($(BUCK_HTTP_CACHE),)
	ifeq ($(BUCK_CACHE_MODE),)
		BUCK_CACHE_MODE=readwrite
	endif
	export BUCK_CACHE_OPTIONS=\
		--config cache.mode=http \
		--config cache.http_url="$(BUCK_HTTP_CACHE)" \
		--config cache.http_mode="$(BUCK_CACHE_MODE)"
endif

ifneq ($(BUCK_DIR_CACHE),)
	export BUCK_CACHE_OPTIONS=\
		--config cache.mode=dir \
		--config cache.dir="$(BUCK_DIR_CACHE)" \
		--config cache.dir_mode="readwrite"
endif

check_env:
ifndef BUCK
	$(error BUCK is not set)
endif
	sh check_env.sh

kill_xcode:
	killall Xcode || true
