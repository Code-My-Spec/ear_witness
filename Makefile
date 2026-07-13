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
  # Force OpenMP OFF: if cmake auto-detects libomp it links ggml against
  # __kmpc_* symbols, but the NIF link below doesn't pull in libomp, so the
  # .so fails to dlopen ("symbol not found: ___kmpc_barrier"). Explicit-off
  # keeps the build deterministic across machines with/without libomp.
  WHISPER_CMAKE_EXTRA = -DGGML_OPENMP=OFF
  # miniaudio's Core Audio backend (see c_src/ear_witness/audio_capture.cpp)
  # needs these three frameworks. MA_NO_RUNTIME_LINKING switches miniaudio
  # from dlopen()-ing them at runtime to a normal direct link — miniaudio's
  # own docs flag runtime linking as an App Store/notarization risk, and
  # this app ships notarized macOS installers (see the
  # desktop-distribution ADR), so pay the direct-link cost up front.
  AUDIO_CXXFLAGS_EXTRA = -DMA_NO_RUNTIME_LINKING
  # -framework Foundation for mac_tap.mm's ObjC bits (NSString/NSUUID/
  # CATapDescription); CoreAudio/AudioToolbox/CoreFoundation are already needed
  # by miniaudio and are reused by the tap (no new frameworks beyond Foundation).
  AUDIO_LDFLAGS = -dynamiclib -undefined dynamic_lookup -framework CoreFoundation -framework CoreAudio -framework AudioToolbox -framework Foundation
  # macOS system-output capture (Core Audio process tap) is a separate ObjC++
  # translation unit linked into the same audio NIF .so — macOS only.
  AUDIO_PLATFORM_OBJS = $(BUILDDIR)/mac_tap.o
else
  PLATFORM_LDFLAGS = -shared -fPIC
  WHISPER_LIB_DIRS = -L$(WHISPER_BUILD)/src -L$(WHISPER_BUILD)/ggml/src
  WHISPER_LIBS = -lwhisper -lggml -lggml-cpu -lggml-base
  PLATFORM_LIBS =
  WHISPER_CMAKE_EXTRA = -DGGML_BLAS=OFF -DGGML_OPENMP=OFF
  # miniaudio's ALSA/PulseAudio backends runtime-link via dlopen and use
  # pthreads (see miniaudio.h's own "Compiling" notes). Covers Linux;
  # Windows (WASAPI, built into the OS) needs no extra libs here.
  AUDIO_LDFLAGS = -shared -fPIC -lpthread -lm -ldl
  AUDIO_CXXFLAGS_EXTRA =
  # No native tap module off macOS — Win/Linux loopback is miniaudio's job.
  AUDIO_PLATFORM_OBJS =
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

# ggml Silero VAD model (not committed to git — ~865KB). Enables whisper's
# Voice Activity Detection in transcribe.cpp (resolve_vad_model_path looks
# for it next to the active model / under models/). When absent the NIF
# falls back to non-VAD transcription, so this is a quality bundle, not a
# hard build dependency. Fetched explicitly like the base model above
# (`make models/ggml-silero-v6.2.0.bin`) — see .code_my_spec/devops/setup.md.
models/ggml-silero-v6.2.0.bin:
	mkdir -p models
	curl -L -o $@ https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v6.2.0.bin

# Compile and link
$(TARGET): $(OBJS) $(WHISPER_LIB)
	$(CXX) $(OBJS) $(LDFLAGS) -o $(TARGET)

# Compile and link the miniaudio capture NIF — no whisper dependency. On
# macOS AUDIO_PLATFORM_OBJS adds the Core Audio process-tap object (mac_tap.o);
# it is empty on Win/Linux so their link is unchanged.
$(AUDIO_TARGET): $(AUDIO_OBJS) $(AUDIO_PLATFORM_OBJS)
	$(CXX) $(AUDIO_OBJS) $(AUDIO_PLATFORM_OBJS) $(AUDIO_LDFLAGS) -o $(AUDIO_TARGET)

# audio_capture.o needs AUDIO_CXXFLAGS_EXTRA (MA_NO_RUNTIME_LINKING on
# macOS) on top of the flags every other object file gets — an explicit
# rule takes precedence over the generic pattern rule below for this one
# target.
$(BUILDDIR)/audio_capture.o: $(SOURCEDIR)/audio_capture.cpp $(BUILDDIR)
	$(CXX) $(CXXFLAGS) $(AUDIO_CXXFLAGS_EXTRA) -c $< -o $@

# macOS-only: Core Audio process tap (system-output capture). ObjC++ (.mm)
# because CATapDescription is an Objective-C class; -fobjc-arc so the tap's
# ObjC objects are reference-counted automatically. Only ever built on macOS
# (AUDIO_PLATFORM_OBJS is empty elsewhere), so this rule never fires on
# Win/Linux even though it's always present.
$(BUILDDIR)/mac_tap.o: $(SOURCEDIR)/mac_tap.mm $(BUILDDIR)
	$(CXX) $(CXXFLAGS) $(AUDIO_CXXFLAGS_EXTRA) -fobjc-arc -x objective-c++ -c $< -o $@

# Compile source files to object files
$(BUILDDIR)/%.o: $(SOURCEDIR)/%.cpp $(BUILDDIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Create build directory if it doesn't exist
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

# Clean up
clean:
	rm -f $(OBJS) $(TARGET) $(AUDIO_OBJS) $(AUDIO_PLATFORM_OBJS) $(AUDIO_TARGET)
	rm -rf $(WHISPER_BUILD)
