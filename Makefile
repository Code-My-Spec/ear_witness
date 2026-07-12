# Variables
WHISPER_DIR = c_src/ear_witness/whisper.cpp
WHISPER_BUILD = $(WHISPER_DIR)/build
WHISPER_LIB = $(WHISPER_BUILD)/src/libwhisper.a
WHISPER_REPO = https://github.com/ggml-org/whisper.cpp.git
WHISPER_TAG = v1.9.1
CXXFLAGS = -fPIC -I$(ERTS_INCLUDE_DIR) -I$(WHISPER_DIR)/include -I$(WHISPER_DIR)/ggml/include -std=c++17

# Per-OS link + build configuration. macOS uses the Accelerate BLAS backend
# (ggml enables it automatically) and needs -undefined dynamic_lookup so the
# emulator resolves enif_* symbols at load time; Linux/Windows build ggml
# CPU-only (no hard OpenBLAS dependency) and a plain -shared leaves the enif_*
# symbols undefined for the emulator to resolve. Static link order matters:
# ggml-blas must precede ggml-base (it depends on its symbols).
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  PLATFORM_LDFLAGS = -dynamiclib -undefined dynamic_lookup
  WHISPER_LIB_DIRS = -L$(WHISPER_BUILD)/src -L$(WHISPER_BUILD)/ggml/src -L$(WHISPER_BUILD)/ggml/src/ggml-blas
  WHISPER_LIBS = -lwhisper -lggml -lggml-cpu -lggml-blas -lggml-base
  PLATFORM_LIBS = -framework Accelerate -framework Foundation
  WHISPER_CMAKE_EXTRA =
else
  PLATFORM_LDFLAGS = -shared -fPIC
  WHISPER_LIB_DIRS = -L$(WHISPER_BUILD)/src -L$(WHISPER_BUILD)/ggml/src
  WHISPER_LIBS = -lwhisper -lggml -lggml-cpu -lggml-base
  PLATFORM_LIBS =
  WHISPER_CMAKE_EXTRA = -DGGML_BLAS=OFF
endif

LDFLAGS = $(PLATFORM_LDFLAGS) $(WHISPER_LIB_DIRS) $(WHISPER_LIBS) $(PLATFORM_LIBS)

PROJECT = nif
BUILDDIR = priv
SOURCEDIR = c_src/ear_witness
TARGET = $(BUILDDIR)/$(PROJECT).so
SOURCES := $(SOURCEDIR)/nif.cpp $(SOURCEDIR)/transcribe.cpp
OBJS = $(patsubst $(SOURCEDIR)/%.cpp,$(BUILDDIR)/%.o,$(SOURCES))

$(info ERTS_INCLUDE_DIR: $(ERTS_INCLUDE_DIR))
$(info WHISPER_DIR: $(WHISPER_DIR))
$(info SOURCES: $(SOURCES))
$(info TARGET: $(TARGET))
$(info UNAME_S: $(UNAME_S))

# Default target
all: $(WHISPER_LIB) $(TARGET)

# Clone whisper.cpp at the pinned tag (not committed to git — too large)
$(WHISPER_DIR)/CMakeLists.txt:
	git clone --depth 1 --branch $(WHISPER_TAG) $(WHISPER_REPO) $(WHISPER_DIR)

# Build whisper static libraries (Metal off: keeps the NIF link simple).
$(WHISPER_LIB): $(WHISPER_DIR)/CMakeLists.txt
	cmake -S $(WHISPER_DIR) -B $(WHISPER_BUILD) \
		-DBUILD_SHARED_LIBS=OFF \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DGGML_METAL=OFF \
		-DWHISPER_BUILD_EXAMPLES=OFF \
		-DWHISPER_BUILD_TESTS=OFF \
		$(WHISPER_CMAKE_EXTRA)
	cmake --build $(WHISPER_BUILD) -j

# Whisper model for the transcription NIF (not committed to git — 148MB)
models/ggml-base.en.bin: $(WHISPER_DIR)/CMakeLists.txt
	sh $(WHISPER_DIR)/models/download-ggml-model.sh base.en
	mkdir -p models
	cp $(WHISPER_DIR)/models/ggml-base.en.bin models/

# Compile and link
$(TARGET): $(OBJS) $(WHISPER_LIB)
	$(CXX) $(OBJS) $(LDFLAGS) -o $(TARGET)

# Compile source files to object files
$(BUILDDIR)/%.o: $(SOURCEDIR)/%.cpp $(BUILDDIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Create build directory if it doesn't exist
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

# Clean up
clean:
	rm -f $(OBJS) $(TARGET)
	rm -rf $(WHISPER_BUILD)
