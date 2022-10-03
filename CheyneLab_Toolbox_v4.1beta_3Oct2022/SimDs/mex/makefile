# new makefile for compiling BW mex functions locally
# requires current copies of ctflib.o and bwlib.o in parent megcode directory

CTF_LIB = ../../../ctflib

# Matlab compiler version on Mac - uses libraries compiled with llvm 5.1 on Yosemite 
mex_mac64 = /Applications/MATLAB_R2018b.app/bin/mex

# Matlab compiler for CentOS 6.0 on VMware 
mex_linux = /usr/local/MATLAB/R2014b/bin/mex

# compile for Windows 10 on VMware using mysys64 install of mingw64
MATLABROOT=c:/Progra~1/MATLAB/R2018b
LIBS= -L$(MATLABROOT)/bin/win64 -L$(MATLABROOT)/extern/lib/win64/microsoft -lmex -lmx -lmwlapack -lmwblas -leng -ladvapi32 -luser32 -lgdi32 -lkernel32 -lmingwex

mex_win64= g++ -static-libgcc -static-libstdc++
MEXFLAG= -m64 -shared -DMATLAB_MEX_FILE -I$(MATLABROOT)/extern/include -Wl,--export-all-symbols $(LIBS)

win64:
	$(mex_win64) $(MEXFLAG) -DMX_COMPAT_32 sim_CTFGetHeader.cc -o sim_CTFGetHeader.mexw64 $(CTF_LIB)/ctflib_win64.o -lws2_32
	$(mex_win64) $(MEXFLAG) sim_filter.cc -o sim_filter.mexw64 $(CTF_LIB)/ctflib_win64.o -lws2_32
	$(mex_win64) $(MEXFLAG) simDsMex.cc -o simDsMex.mexw64 $(CTF_LIB)/ctflib_win64.o -lws2_32
	$(mex_win64) $(MEXFLAG) sim_CTFGetAverage.cc -o sim_CTFGetAverage.mexw64 $(CTF_LIB)/ctflib_win64.o -lws2_32
	mv *.mexw64 ../
linux64:
	$(mex_linux) sim_CTFGetHeader.cc $(CTF_LIB)/ctflib_glx64.o
	$(mex_linux) sim_filter.cc $(CTF_LIB)/ctflib_glx64.o
	$(mex_linux) simDsMex.cc $(CTF_LIB)/ctflib_glx64.o
	$(mex_linux) sim_CTFGetAverage.cc $(CTF_LIB)/ctflib_glx64.o
	mv *.mexa64 ../

imac64:
	$(mex_mac64) sim_filter.cc $(CTF_LIB)/ctflib_maci64.o
	$(mex_mac64) simDsMex.cc $(CTF_LIB)/ctflib_maci64.o
	$(mex_mac64) sim_CTFGetAverage.cc $(CTF_LIB)/ctflib_maci64.o
	$(mex_mac64) -DMX_COMPAT_32 sim_CTFGetHeader.cc $(CTF_LIB)/ctflib_maci64.o
	mv *.mexmaci64 ../
