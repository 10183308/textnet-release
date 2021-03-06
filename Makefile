CONFIG_FILE := Makefile.config
include $(CONFIG_FILE)

# set LD_LIBRARY_PATH
export CC  = gcc
export CXX = g++
export NVCC = $(CUDA_DIR)/bin/nvcc

# Custom compiler
ifdef CUSTOM_CXX
    CXX := $(CUSTOM_CXX)
endif

ifeq ($(COMPILE_VERSION), debug)
CXXFLAGS += -g -Ddebug -I./mshadow/ -std=c++11
else
#CXXFLAGS += -Wall -O3 -msse3 -Wno-unknown-pragmas -funroll-loops -I./mshadow/ -std=c++11
CXXFLAGS += -O3 -msse3 -Wno-unknown-pragmas -funroll-loops -I./mshadow/ -std=c++11
endif

CUDA_INCLUDE_DIR := $(CUDA_DIR)/include
CUDA_LIB_DIR := $(CUDA_DIR)/lib64

INCLUDE_DIRS += $(CUDA_INCLUDE_DIR)
LIBRARY_DIRS += $(CUDA_LIB_DIR)

# Complete build flags.
COMMON_FLAGS += $(foreach includedir,$(INCLUDE_DIRS),-I$(includedir))
CXXFLAGS += -pthread -fPIC $(COMMON_FLAGS) $(WARNINGS)
NVCCFLAGS += -ccbin=$(CXX) -Xcompiler -fPIC $(COMMON_FLAGS) --use_fast_math -g -O3
LINKFLAGS += -fPIC $(COMMON_FLAGS) $(WARNINGS)
LDFLAGS += $(foreach librarydir,$(LIBRARY_DIRS),-L$(librarydir)) \
        $(foreach library,$(LIBRARIES),-l$(library))
 
export NVCCFLAGS = --use_fast_math -g -O3 -ccbin $(CXX)

# specify tensor path
# BIN = bin/textnet bin/grad_check bin/textnet_testonly# bin/textnet_test bin/textnet_matching bin/textnet_senti bin/textnet_nb
BIN = bin/textnet bin/grad_check bin/textnet_test # bin/textnet_testonly bin/textnet_multi#bin/textnet_test bin/textnet_matching bin/textnet_senti bin/textnet_nb
OBJ = layer_cpu.o initializer_cpu.o updater_cpu.o checker_cpu.o io.o settingv.o net_cpu.o 
CUOBJ = layer_gpu.o initializer_gpu.o updater_gpu.o checker_gpu.o net_gpu.o
STATISTIC = statistic.h

# define it to use cpu only
ifeq ($(CPU_ONLY), 1)
    CXXFLAGS += -DMSHADOW_USE_CUDA=0
    CUOBJ = 
    LDFLAGS += -lm -lpthread -lz
else
    LDFLAGS += -lm -lpthread -lz -lcudart -lcublas -lcurand
endif

# use mkl
ifeq ($(BLAS), mkl)
    CXXFLAGS += -DMSHADOW_USE_MKL=1
    LDFLAGS += -lmkl_core -lmkl_intel_lp64 -lmkl_intel_thread -liomp5
else
    CXXFLAGS += -DMSHADOW_USE_MKL=0
endif

# use cblas
ifeq ($(BLAS), cblas)
    CXXFLAGS += -DMSHADOW_USE_CBLAS=1
    LDFLAGS += -lcblas
else
    CXXFLAGS += -DMSHADOW_USE_CBLAS=0
endif

# use zmq
ifeq ($(REALTIME_SERVER), 1)
    CXXFLAGS += -DREALTIME_SERVER=1
    LDFLAGS += -lzmq
else
    CXXFLAGS += -DREALTIME_SERVER=0
endif

all: $(MK_BIN) $(BIN)

$(MK_BIN):
	mkdir bin

layer_cpu.o layer_gpu.o: src/layer/layer_impl.cpp src/layer/layer_impl.cu\
	src/layer/*.h src/layer/*.hpp src/layer/common/*.hpp src/layer/input/*.hpp src/layer/loss/*.hpp src/utils/*.h

updater_cpu.o updater_gpu.o: src/updater/updater_impl.cpp src/updater/updater_impl.cu\
	src/updater/*.hpp src/updater/*.h src/utils/*.h
  
initializer_cpu.o initializer_gpu.o: src/initializer/initializer_impl.cpp src/initializer/initializer_impl.cu\
  src/initializer/*.hpp src/initializer/*.h src/utils/*.h
  
checker_cpu.o checker_gpu.o: src/checker/checker_impl.cpp src/checker/checker_impl.cu\
  src/checker/*.hpp src/checker/*.h src/utils/*.h
 
net_cpu.o net_gpu.o: src/net/net_impl.cpp src/net/net_impl.cu\
	src/net/*.h src/net/*.hpp
 
statistic.h: src/statistic/statistic.h

io.o: src/io/jsoncpp.cpp src/io/json/*.* 

settingv.o: src/utils/settingv.cpp src/utils/*.h


bin/textnet: src/textnet_main.cpp $(OBJ) $(CUOBJ) $(STATISTIC)
# bin/textnet_multi: src/textnet_multi.cpp $(OBJ) $(CUOBJ) $(STATISTIC)
# bin/textnet_testonly: src/textnet_testonly.cpp $(OBJ) $(CUOBJ) $(STATISTIC)
# bin/textnet_matching: src/textnet_matching.cpp $(OBJ) $(CUOBJ)
# bin/textnet_senti: src/textnet_senti.cpp $(OBJ) $(CUOBJ)
# bin/textnet_nb: src/textnet_nextbasket.cpp $(OBJ) $(CUOBJ)
bin/grad_check: src/grad_check.cpp $(OBJ) $(CUOBJ)
bin/textnet_test: src/textnet_test.cpp $(OBJ) $(CUOBJ)
# bin/textnet_test: src/textnet_test.cpp $(OBJ) $(CUOBJ)

$(BIN) :
	$(CXX) $(CXXFLAGS)  -o $@ $(filter %.cpp %.o %.c %.a, $^) $(LDFLAGS)

$(OBJ) :
	$(CXX) -c $(CXXFLAGS) -o $@ $(firstword $(filter %.cpp %.c, $^) )

$(CUOBJ) :
	$(NVCC) -c -o $@ $(NVCCFLAGS) -std=c++11 -Xcompiler "$(CXXFLAGS)" $(filter %.cu, $^)

$(CUBIN) :
	$(NVCC) -o $@ $(NVCCFLAGS) -std=c++11 -Xcompiler "$(CXXFLAGS)" -Xlinker "$(LDFLAGS)" $(filter %.cu %.cpp %.o, $^)
  
clean:
	$(RM) $(OBJ) $(BIN) $(CUBIN) $(CUOBJ) *~ */*~ */*/*~



