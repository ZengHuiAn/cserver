

(cd thirdpart/LuaJIT-2.0.0/ && make && cp -v src/libluajit.a ../../lib/ )
(cd thirdpart/mxml-2.7 && ./configure --disable-threads && make && cp -v libmxml.a ../../lib)
(cd thirdpart/pbc && make && cp -v build/libpbc.a ../../lib)



