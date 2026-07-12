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
  # miniaudio's Core Audio backend (see c_src/ear_witness/audio_capture.cpp)
  # needs these three frameworks. MA_NO_RUNTIME_LINKING switches miniaudio
  # from dlopen()-ing them at runtime to a normal direct link — miniaudio's
  # own docs flag runtime linking as an App Store/notarization risk, and
  # this app ships notarized macOS installers (see the
  # desktop-distribution ADR), so pay the direct-link cost up front.
  AUDIO_CXXFLAGS_EXTRA = -DMA_NO_RUNTIME_LINKING
  AUDIO_LDFLAGS = -dynamiclib -undefined dynamic_lookup -framework CoreFoundation -framework CoreAudio -framework AudioToolbox
else
  PLATFORM_LDFLAGS = -shared -fPIC
  WHISPER_LIB_DIRS = -L$(WHISPER_BUILD)/src -L$(WHISPER_BUILD)/ggml/src
  WHISPER_LIBS = -lwhisper -lggml -lggml-cpu -lggml-base
  PLATFORM_LIBS =
  WHISPER_CMAKE_EXTRA = -DGGML_BLAS=OFF
  # miniaudio's ALSA/PulseAudio backends runtime-link via dlopen and use
  # pthreads (see miniaudio.h's own "Compiling" notes). Covers Linux;
  # Windows (WASAPI, built into the OS) needs no extra libs here.
  AUDIO_LDFLAGS = -shared -fPIC -lpthread -lm -ldl
  AUDIO_CXXFLAGS_EXTRA =
endif

LDFLAGS = $(PLATFORM_LDFLAGS) $(WHISPER_LIB_DIRS) $(WHISPER_LIBS) $(PLATFORM_LIBS)

PROJECT = nif
BUILDDIR = priv
SOURCEDIR = c_src/ear_witness
TARGET = $(BUILDDIR)/$(PROJECT).so
SOURCES := $(SOURCEDIR)/nif.cpp $(SOURCEDIR)/transcribe.cpp
OBJS = $(patsubst $(SOURCEDIR)/%.cpp,$(BUILDDIR)/%.o,$(SOURCES))

# miniaudio capture NIF (c_src/ear_witness/audio_capture.cpp, vendoring the
# single-header c_src/miniaudio.h) — a separate .so from the whisper NIF
# above, built and linked independently so whisper's build stays untouched.
AUDIO_PROJECT = audio_capture_nif
AUDIO_TARGET = $(BUILDDIR)/$(AUDIO_PROJECT).so
AUDIO_SOURCES := $(SOURCEDIR)/audio_capture.cpp
AUDIO_OBJS = $(patsubst $(SOURCEDIR)/%.cpp,$(BUILDDIR)/%.o,$(AUDIO_SOURCES))

$(info ERTS_INCLUDE_DIR: $(ERTS_INCLUDE_DIR))
$(info WHISPER_DIR: $(WHISPER_DIR))
$(info SOURCES: $(SOURCES))
$(info TARGET: $(TARGET))
$(info AUDIO_TARGET: $(AUDIO_TARGET))
$(info UNAME_S: $(UNAME_S))

# Default target
all: $(WHISPER_LIB) $(TARGET) $(AUDIO_TARGET)

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

# Compile and link the miniaudio capture NIF — no whisper dependency.
$(AUDIO_TARGET): $(AUDIO_OBJS)
	$(CXX) $(AUDIO_OBJS) $(AUDIO_LDFLAGS) -o $(AUDIO_TARGET)

# audio_capture.o needs AUDIO_CXXFLAGS_EXTRA (MA_NO_RUNTIME_LINKING on
# macOS) on top of the flags every other object file gets — an explicit
# rule takes precedence over the generic pattern rule below for this one
# target.
$(BUILDDIR)/audio_capture.o: $(SOURCEDIR)/audio_capture.cpp $(BUILDDIR)
	$(CXX) $(CXXFLAGS) $(AUDIO_CXXFLAGS_EXTRA) -c $< -o $@

# Compile source files to object files
$(BUILDDIR)/%.o: $(SOURCEDIR)/%.cpp $(BUILDDIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Create build directory if it doesn't exist
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

# Clean up
clean:
	rm -f $(OBJS) $(TARGET) $(AUDIO_OBJS) $(AUDIO_TARGET)
	rm -rf $(WHISPER_BUILD)
