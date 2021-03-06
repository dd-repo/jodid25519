# Site-dependent variables
BUILDDIR = build
NODE_PATH = ./node_modules
NPM = npm
NODE = node

# Dependencies - make sure you keep DEP_ALL and DEP_ALL_NAMES up-to-date
DEP_ASMCRYPTO = $(NODE_PATH)/asmcrypto.js/asmcrypto.js
DEP_JSBN = $(NODE_PATH)/jsbn/index.js
DEP_NONCUSTOM = $(DEP_JSBN)
DEP_NONCUSTOM_NAMES = jsbn
DEP_ALL = $(DEP_ASMCRYPTO) $(DEP_NONCUSTOM)
DEP_ALL_NAMES = asmcrypto.js $(DEP_NONCUSTOM_NAMES)

# Build-depends - make sure you keep BUILD_DEP_ALL and BUILD_DEP_ALL_NAMES up-to-date
KARMA  = $(NODE_PATH)/karma/bin/karma
JSDOC  = $(NODE_PATH)/.bin/jsdoc
R_JS   = $(NODE_PATH)/.bin/r.js
ALMOND = $(NODE_PATH)/almond/almond.js
R_JS_ALMOND_OPTS = baseUrl=src name=../$(ALMOND:%.js=%) wrap.startFile=almond.0 wrap.endFile=almond.1
UGLIFY = $(NODE_PATH)/.bin/uglifyjs
BUILD_DEP_ALL = $(KARMA) $(JSDOC) $(R_JS) $(ALMOND) $(UGLIFY)
BUILD_DEP_ALL_NAMES = karma jsdoc requirejs almond uglify-js

ASMCRYPTO_MODULES = utils,globals,aes-cbc,aes-ccm,sha1,sha256,sha512,hmac-sha1,hmac-sha256,hmac-sha512,pbkdf2-hmac-sha1,pbkdf2-hmac-sha256,pbkdf2-hmac-sha512,rng,bn,rsa-pkcs1,rng-globals

all: test api-doc dist test-shared

dist: $(BUILDDIR)/jodid25519-shared.min.js $(BUILDDIR)/jodid25519-static.js

test-timing:
	KARMA_FLAGS='--preprocessors=' TEST_TIMING=true $(MAKE) test

test-full:
	KARMA_FLAGS='--preprocessors=' TEST_FULL=true $(MAKE) test

test: $(KARMA) $(R_JS) $(DEP_ALL)
	$(NODE) $(KARMA) start $(KARMA_FLAGS) --singleRun=true karma.conf.js --colors=false --browsers PhantomJS

api-doc: $(JSDOC)
	$(NODE) $(JSDOC) --destination doc/api/ --private \
                 --configure jsdoc.json \
                 --recurse src/

$(BUILDDIR)/build-config-static.js: src/config.js Makefile
	mkdir -p $(BUILDDIR)
	tail -n+2 "$<" > "$@"

$(BUILDDIR)/build-config-shared.js: src/config.js Makefile
	mkdir -p $(BUILDDIR)
	tail -n+2 "$<" > "$@.tmp"
	for i in $(DEP_ALL_NAMES); do \
		sed -i -e "s,node_modules/$$i/.*\",build/$$i-dummy\"," "$@.tmp"; \
		touch $(BUILDDIR)/$$i-dummy.js; \
	done
	mv "$@.tmp" "$@"

$(BUILDDIR)/jodid25519-static.js: build-static
build-static: $(R_JS) $(ALMOND) $(BUILDDIR)/build-config-static.js $(DEP_ALL)
	$(NODE) $(R_JS) -o $(BUILDDIR)/build-config-static.js out="$(BUILDDIR)/jodid25519-static.js" \
	  $(R_JS_ALMOND_OPTS) include=jodid25519 optimize=none

$(BUILDDIR)/jodid25519-shared.js: build-shared
build-shared: $(R_JS) $(ALMOND) $(BUILDDIR)/build-config-shared.js
	$(NODE) $(R_JS) -o $(BUILDDIR)/build-config-shared.js out="$(BUILDDIR)/jodid25519-shared.js" \
	  $(R_JS_ALMOND_OPTS) include=jodid25519 optimize=none

test-static: test/build-test-static.js build-static
	./$< ../$(BUILDDIR)/jodid25519-static.js

test-shared: test/build-test-shared.js build-shared $(DEP_ALL)
	./$< ../$(BUILDDIR)/jodid25519-shared.js $(DEP_ALL)

$(BUILDDIR)/%.min.js: $(BUILDDIR)/%.js $(UGLIFY)
	$(NODE) $(UGLIFY) $< -o $@ --source-map $@.map --mangle --compress --lint

jodid25519.js: $(BUILDDIR)/jodid25519-shared.min.js
	sed -e 's,$<,$@,g' "$<.map" > "$@.map"
	sed -e 's,$<,$@,g' "$<" > "$@"

# TODO: this may be removed when the default dist of asmcrypto includes sha512
$(DEP_ASMCRYPTO): $(DEP_ASMCRYPTO).with.sha512
$(DEP_ASMCRYPTO).with.sha512:
	$(NPM) install asmcrypto.js
	cd $(NODE_PATH)/asmcrypto.js &&	$(NPM) install && $(NODE) $(NODE_PATH)/.bin/grunt --with=$(ASMCRYPTO_MODULES)
	touch $(DEP_ASMCRYPTO).with.sha512

# annoyingly, npm sets mtime to package publish date so we have to use |-syntax
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
$(BUILD_DEP_ALL) $(DEP_NONCUSTOM): | .npm-build-deps
	$(NPM) install $(BUILD_DEP_ALL_NAMES) $(DEP_NONCUSTOM_NAMES)

# Other things from package.json, such as karma plugins. we touch a guard file
# to prevent "npm install" running on every invocation of `make test`.
.npm-build-deps: package.json
	$(NPM) install
	touch .npm-build-deps

clean:
	rm -rf doc/api/ coverage/ build/ jodid25519.js test-results.xml

clean-all: clean
	rm -f $(BUILD_DEP_ALL) $(DEP_ALL)
	rm -rf $(BUILD_DEP_ALL_NAMES:%=$(NODE_PATH)/%) $(DEP_ALL_NAMES:%=$(NODE_PATH)/%)
	rm -f .npm-build-deps

.PHONY: all test api-doc clean clean-all
.PHONY: build-static build-shared test-static test-shared dist
