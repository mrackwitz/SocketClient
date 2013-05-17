### Programs and Options Used in Commands

XCODE_BUILD_OPTS = -arch i386 VALID_ARCHS=i386 ARCH=i386 ONLY_ACTIVE_ARCH=NO

XCODE_BUILD_WORKSPACE = xcodebuild \
		-workspace SocketShuttle.xcworkspace \
		-sdk iphonesimulator \
		$(XCODE_BUILD_OPTS)

FOREVER = mkdir -p build/forever && server/node_modules/forever/bin/forever -w \
		-c coffee \
		-m 1 \
		-o $(CURDIR)/build/forever/server.out \
		--pidFile $(CURDIR)/build/forever/server.pid \
		--minUptime 1000 \
		--spinSleepTime 1000 \

SERVER_EXECUTABLE = server/faye_server.coffee


### Installation Targets:

# Execute this once
install: update-submodules install-deps build-doc

# Install all dependencies
install-deps: program-appledoc install-server-deps

# Update submodules, and init if they are not initialized
update-submodules:
	git submodule update --init --recursive


### Build & Run Targets
default: build-framework

# Build the framework
build-framework:
	$(XCODE_BUILD_WORKSPACE) -scheme SocketShuttleFramework clean build

# Execute tests
test: run-server
	$(XCODE_BUILD_WORKSPACE) -scheme SocketShuttleTests clean build

# Clean build
clean:
	$(XCODE_BUILD_WORKSPACE) -scheme SocketShuttleFramework clean
	$(XCODE_BUILD_WORKSPACE) -scheme SocketShuttleTests clean
	rm -rf build


### Server Targets:

# Install dependecies
install-server-deps: program-npm
	cd server; \
	npm install

# Start server
start-server: install-server-deps
	$(FOREVER) start $(SERVER_EXECUTABLE)

# Stop server
stop-server:
	$(FOREVER) stop $(SERVER_EXECUTABLE)


### Documentation Targets:

# Open doc
doc: build-doc
	open build/doc/html/index.html

# Build doc
build-doc:
	mkdir -p build/doc
	sh bin/build_appledoc.sh
	rm build/doc/docset-installed.txt

# Publish doc to gh-pages
publish-doc: build-doc
	cd pages; \
	git checkout -B gh-pages; \
	cp -R ../build/* .; \
	git add -A; \
	git commit -m "Updated doc"; \
	git push origin gh-pages


### Support Targets:
# Used to ensure that required command are installed, and use brew as fallback to install
# required programs, which was not found in current path

# Check if a program is available
check-program-%:
	@which $* > /dev/null

# Brew has a custom installer
install-program-brew:
	ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go)"

# All other programs will be installed using brew
install-program-%:	
	${MAKE} program-brew
	brew install $*

# Require a program: if it is available, do nothing, otherwise try to install it
program-%:
	${MAKE} check-program-$* || ${MAKE} install-program-$*
