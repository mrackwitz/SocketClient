# SocketShuttle

SocketShuttle is a Bayeux client implementation on top of [SocketRocket](https://github.com/square/SocketRocket), which is used as transport layer.


## TODO

* ~~Basic example~~
    * ~~Create a basic Bayeux sample server~~
    * ~~Create a basic sample app~~
* Implement structured unit tests
    * Add a test server
    * Port [Faye's client cases](https://github.com/faye/faye/blob/master/spec/javascript/client_spec.js) to Cocoa/ObjC
* Support ```hosts``` advice
* Add method to delegate protocol which allows intercept and modify all non meta messages
* Add Target to build for OS X


## Installation instructions

### Use as Submodule and target dependency

1. Execute ```git submodule add git@github.com:mrackwitz/SocketShuttle.git vendor/SocketShuttle```.

2. ```open vendor/SocketShuttle```

3. Drop **SocketShuttle.xcodeproj** in your project navigator.

    ![Step 3](http://mrackwitz.github.io/SocketShuttle/images/step_3.png)

4. Add ![Target SocketShuttle](http://mrackwitz.github.io/SocketShuttle/images/target.png).

    ![Step 4](http://mrackwitz.github.io/SocketShuttle/images/step_4.png)

5. Add library **libSocketShuttle.a** to your project.

    ![Step 5](http://mrackwitz.github.io/SocketShuttle/images/step_5.png)

6. Add library **libicucore.dylib** to your project.

    ![Step 6](http://mrackwitz.github.io/SocketShuttle/images/step_6.png)

7. (Ensure that library was placed in group **Frameworks**.)

    ![Step 7](http://mrackwitz.github.io/SocketShuttle/images/step_7.png)

8. ```import <SocketShuttle/SocketShuttle.h>``` where ever you want to use the library. You could add it to your header prefix file, if you want.


## Usage

See the provided example app and the [documentation](http://mrackwitz.github.io/SocketShuttle/doc/html/index.html) for more information.


## Credits

* jverkoey's [iOS-Framework](https://github.com/jverkoey/iOS-Framework) licensed under <a rel="license" href="http://creativecommons.org/licenses/by/3.0/"><img alt="Creative Commons License" style="border-width:0" src="http://i.creativecommons.org/l/by/3.0/88x31.png" /></a>.
* Square's [SocketRocket](https://github.com/square/SocketRocket) licensed under [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).


## License

Copyright (c) 2013 Marius Rackwitz <marius@paij.com>

The MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

