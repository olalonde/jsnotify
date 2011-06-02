This tutorial was originally posted here: [http://syskall.com/how-to-roll-out-your-own-javascript-api-with](http://syskall.com/how-to-roll-out-your-own-javascript-api-with)

##Introduction##

This tutorial will teach you how to:

1. Compile the V8 Javascript engine 
2. Bind a Javascript function to your own C++ function

For the sake of demonstration and to impress your co-workers, we will bind a Javascript function "alert()“ that will display desktop notifications through the GTK library. Here’s what the end result looks like:

![jsnotify screenshot](http://i.imgur.com/nUsWG.png)

You can get the full source code of this tutorial [from github](https://github.com/olalonde/jsnotify):

    git clone git://github.com/olalonde/jsnotify.git

This tutorial was tested on Ubuntu 10.04 and 10.10 64-bit but should work fine on any Linux distribution. The notification part requires the GTK+ library. 

##Compiling Google’s V8 Javascript engine##

First, let’s make sure we have all the [required tools and dependencies](http://code.google.com/apis/v8/build.html) to compile. 

    sudo apt-get install build-essential scons subversion 


 - The build-essential package is a meta package that installs all the necessary tools and libraries to compile C++ programs. 
 - SCons is a build tool which attempts to replace the classic “make” and is used by the V8 project.
 - Subversion is needed to checkout the source code of V8.

Now, let’s grab V8’s source from the [official repository](http://code.google.com/p/v8/wiki/Source?tm=4): 

    svn checkout http://v8.googlecode.com/svn/trunk/ v8 

We can now move into the V8 directory and try to compile! 

    cd v8;
    scons arch=x64; 

The “arch=x64” option specifies that we want to build a 64-bit version of V8 (the default value would be 32-bit otherwise).

If V8 compiled fine, you should now have a libv8.a file in your v8/ directory. As you probably guessed, libv8.a is the library that our C++ program will use to execute Javascript code.

So, if everything compiled fine, just skip to the next section. Otherwise, keep on reading. 

When you get errors as a result of compiling third party code, it is usually due to the fact that the compiler can’t find required libraries (/usr/lib) and/or their associated header files (/usr/lib/include). The latter are usually available through packages conventionally named *libname*-dev . In order to find out which package installs a given file, there is a neat utility called `apt-file`.  

    sudo apt-get install apt-file;
    apt-file search missing-header-file.h; 

The `apt-file search` command lists the package(s) that install a given file (*missing-header-file.h* in this case). If there are more than one package listed, we have to take a semi-educated guess on which package we should install based on its name (let me know in the comments if you know of a better trick!). We then simply install the package with the usual `apt-get install package-name` command. 

Hint: If you are on Ubuntu 10.04, you might need to install the following packages:

    sudo apt-get install libc6-dev-i368 lib32stdc++6

Now that we’ve installed all the missing files, the compilation should work. Let's move on to the next section.

If you are still stuck with compiling V8, [this tutorial](http://www.travisswicegood.com/2009/07/11/compiling-node-js-olibc6-dev-i368n-ubuntu-9-04/) might help. 

##Building our own Javascript API##

Now that we have successfully compiled the V8 library, we will build our own C++ project that will be “Javascript scriptable”. This means that our program will be able to run Javascript code which in turn will be able to call our custom C++ functions. 

*Note:* You can also get the full source code of this tutorial from my [jsnotify github repository]((https://github.com/olalonde/jsnotify)): `git clone git://github.com/olalonde/jsnotify.git` 

First let’s create our file structure.

    jsnotify/
      |-- deps/  # third party code
      |   `-- v8  # move your v8 folder here
      `-- src/ # our code goes here
          `-- jsnotify.cpp

Now let’s copy the sample code available at `deps/v8/samples/shell.cc` and paste it into jsnotify.cpp. The sample code given by V8 let’s you execute a Javascript file or start an interactive Javascript shell. It also binds some useful Javascript functions such as print() which will output text to the terminal. 

Let’s try to compile this! 

    g++ src/jsnotify.cpp; 

Of course, this gives us a bunch of errors since we haven’t specified where the V8 header and library files are. Let’s try again! 

    g++ src/jsnotify.cpp -Ideps/v8/include -Ldeps/v8/ -lv8

Oops, still some errors. Looks like we also have to link the pthread library.

    g++ src/jsnotify.cpp -Ideps/v8/include -Ldeps/v8/ -lv8 -lpthread

This finally compiles! Now that we have our mini Javascript shell, let’s play a bit with it.

    $ ./a.out 
    V8 version 3.1.5
    > var foo = “Hello World”;
    > print(foo);
    Hello World

Now, all we have to do is to create our custom alert() function in C++.

    #!cpp
    // INSERT THIS BEFORE int RunMain(int argc, char* argv[]) {
    // We need those two libraries for the GTK+ notification 
    #include <gtkmm.h>
    #include <libnotifymm.h>
    v8::Handle<v8::Value> Alert(const v8::Arguments& args);

    // INSERT THIS AT END OF FILE   
    // The callback that is invoked by v8 whenever the JavaScript 'alert'
    // function is called.  Displays a GTK+ notification.
    v8::Handle<v8::Value> Alert(const v8::Arguments& args) {
      v8::String::Utf8Value str(args[0]); // Convert first argument to V8 String
      const char* cstr = ToCString(str); // Convert V8 String to C string
      
      Notify::init("Basic");
      // Arguments: title, content, icon
      Notify::Notification n("Alert", cstr, "terminal");
      // Display notification
      n.show();
      
      return v8::Undefined();
    }

Now that we have our Alert C++ function, we need to tell V8 to bind it to the Javascript alert() function. This is done by adding the following code in the RunMain function:

    #!cpp
    // INSERT AFTER v8::Handle<v8::ObjectTemplate> global = v8::ObjectTemplate::New();
    // Bind the global 'alert' function to the C++ Alert callback.
    global->Set(v8::String::New("alert"), v8::FunctionTemplate::New(Alert));

Now, in order to compile, the compiler needs to know where to find the two header files we introduced. This is done using the pkg-config utility: 

    g++ src/jsnotify.cpp -Ideps/v8/include -Ldeps/v8/ -lv8 -lpthread `pkg-config --cflags --libs gtkmm-2.4 libnotifymm-1.0`

We can now try our new alert function.

    $./a.out 
    V8 version 3.1.5
    > alert(“wow, it works!”);  

You should see a nice notification in the top right of your screen! Note that you can also put you Javascript code in a file and pass the file name as an argument `./a.out filename.js`. 

##Conclusion##

It's quite easy to make a C++ program "Javascriptable" with V8 and the proper setup. If you'd like to practice your newfound skills, I suggest you try to add a title argument to the alert function. You might also want to follow me on Posterous if you'd like to be informed when I post the follow up to this tutorial which will explain how to extend [Node.js](http://nodejs.org/) with our alert function.

That’s all for today, thanks for reading! Let me know in the comments if you run into any problem, I’ll be glad to help. 

*If you liked this, maybe you'd also like what I [tweet on Twitter](http://twitter.com/o_lalonde)!*
