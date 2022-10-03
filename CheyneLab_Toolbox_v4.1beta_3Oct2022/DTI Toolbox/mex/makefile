# new makefile for compiling mex functions locally
# D. Cheyne Oct, 2021

# Matlab compiler version on Mac 10.14
# using XCode 10 Apple LLVM version 10.0.0 (clang-1000.11.45.2)
#
mex_mac64 = /Applications/MATLAB_R2018b.app/bin/mex

# Matlab compiler for CentOS 6.0 on VMware 
mex_linux = /usr/local/MATLAB/R2014b/bin/mex

# compile for Windows 10 on msys2 mingw64 from Cecilia's notes
# added static linking of stdlibcc and libstdc++ to eliminate need to have local copy of stdlibg++-6.dll
# inclusion of lpthread will require winpthread-1.dll

MATLABROOT=c:/Progra~1/MATLAB/R2018b
LIBS= -L$(MATLABROOT)/bin/win64 -L$(MATLABROOT)/extern/lib/win64/microsoft -lmex -lmx -lmwlapack -lmwblas -leng -ladvapi32 -luser32 -lgdi32 -lkernel32 -lmingwex

mex_win64= g++ -static-libgcc -static-libstdc++
MEXFLAG= -m64 -shared -DMATLAB_MEX_FILE -I$(MATLABROOT)/extern/include -Wl,--export-all-symbols $(LIBS)

win64:
	$(mex_win64) $(MEXFLAG) dt_computeFaceNormals.cc -o dt_computeFaceNormals.mexw64 -lws2_32
	$(mex_win64) $(MEXFLAG) trilinear.cpp -o trilinear.mexw64 -lws2_32

# move to parent directory on windows - assumes running on linux-like msys2 environment
	mv *.mexw64 ../

linux64:
	$(mex_linux) dt_computeFaceNormals.cc
	$(mex_linux) trilinear.cpp
	mv *.mexa64 ../

imac64:
	$(mex_mac64) dt_computeFaceNormals.cc
	$(mex_mac64) trilinear.cpp

	mv *.mexmaci64 ../
