jsnotify : jsnotify.o deps/v8/libv8.a
	g++ -o jsnotify obj/jsnotify.o -L./deps/v8 -lv8 -lpthread `pkg-config --libs gtkmm-2.4 libnotifymm-1.0`

jsnotify.o : src/jsnotify.cpp
	g++ -o obj/jsnotify.o -c -O2 -I./deps/v8/include `pkg-config --cflags gtkmm-2.4 libnotifymm-1.0` src/jsnotify.cpp
	
deps/v8/libv8.a:
	if test -d deps/v8; \
	  then echo "V8 already checked out"; \
	else \
	  svn checkout http://v8.googlecode.com/svn/trunk/ deps/v8; \
	fi
	cd deps/v8 && scons arch=x64
