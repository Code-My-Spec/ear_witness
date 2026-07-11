# Variables
WHISPER_DIR = c_src/todo_app/whisper.cpp
WHISPER_BUILD = $(WHISPER_DIR)/build
WHISPER_LIB = $(WHISPER_BUILD)/src/libwhisper.a
WHISPER_REPO = https://github.com/ggml-org/whisper.cpp.git
WHISPER_TAG = v1.9.1
CXXFLAGS = -fPIC -I$(ERTS_INCLUDE_DIR) -I$(WHISPER_DIR)/include -I$(WHISPER_DIR)/ggml/include -std=c++17
LDFLAGS = -dynamiclib -undefined dynamic_lookup \
	-L$(WHISPER_BUILD)/src \
	-L$(WHISPER_BUILD)/ggml/src \
	-L$(WHISPER_BUILD)/ggml/src/ggml-blas \
	-lwhisper -lggml -lggml-cpu -lggml-blas -lggml-base \
	-framework Accelerate -framework Foundation

PROJECT = nif
BUILDDIR = priv
SOURCEDIR = c_src/todo_app
TARGET = $(BUILDDIR)/$(PROJECT).so
SOURCES := $(SOURCEDIR)/nif.cpp $(SOURCEDIR)/transcribe.cpp
OBJS = $(patsubst $(SOURCEDIR)/%.cpp,$(BUILDDIR)/%.o,$(SOURCES))

$(info ERTS_INCLUDE_DIR: $(ERTS_INCLUDE_DIR))
$(info WHISPER_DIR: $(WHISPER_DIR))
$(info SOURCES: $(SOURCES))
$(info TARGET: $(TARGET))

# Default target
all: $(WHISPER_LIB) $(TARGET)

# Clone whisper.cpp at the pinned tag (not committed to git — too large)
$(WHISPER_DIR)/CMakeLists.txt:
	git clone --depth 1 --branch $(WHISPER_TAG) $(WHISPER_REPO) $(WHISPER_DIR)

# Build whisper static libraries (Metal off: keeps the NIF link simple; Accelerate BLAS on)
$(WHISPER_LIB): $(WHISPER_DIR)/CMakeLists.txt
	cmake -S $(WHISPER_DIR) -B $(WHISPER_BUILD) \
		-DBUILD_SHARED_LIBS=OFF \
		-DGGML_METAL=OFF \
		-DWHISPER_BUILD_EXAMPLES=OFF \
		-DWHISPER_BUILD_TESTS=OFF
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
