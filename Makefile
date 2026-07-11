# Variables
WHISPER_DIR = c_src/todo_app/whisper.cpp
WHISPER_LIB = $(WHISPER_DIR)/libwhisper.a
WHISPER_REPO = https://github.com/ggml-org/whisper.cpp.git
WHISPER_COMMIT = bf4cb4abad4e35c74b387df034cc4ac7b22e5fe6
CXXFLAGS = -fPIC -I$(ERTS_INCLUDE_DIR) -I$(WHISPER_DIR) -std=c++11
LDFLAGS = -dynamiclib -undefined dynamic_lookup -L$(WHISPER_DIR) -lwhisper

PROJECT = nif
BUILDDIR = priv
SOURCEDIR = c_src/todo_app
TARGET = $(BUILDDIR)/$(PROJECT).so
SOURCES := $(SOURCEDIR)/nif.cpp $(SOURCEDIR)/transcribe.cpp
OBJS = $(patsubst $(SOURCEDIR)/%.cpp,$(BUILDDIR)/%.o,$(SOURCES))

$(info ERTS_INCLUDE_DIR: $(ERTS_INCLUDE_DIR))
$(info WHISPER_DIR: $(WHISPER_DIR))
$(info SOURCES: $(SOURCES))
$(info OBJ: $(OBJ))
$(info TARGET: $(TARGET))

# Default target
all: $(WHISPER_LIB) $(TARGET)

# Clone whisper.cpp at the pinned commit (not committed to git — too large)
$(WHISPER_DIR)/Makefile:
	git clone $(WHISPER_REPO) $(WHISPER_DIR)
	cd $(WHISPER_DIR) && git checkout $(WHISPER_COMMIT)

# Build whisper library
$(WHISPER_LIB): $(WHISPER_DIR)/Makefile
	$(MAKE) -C $(WHISPER_DIR) libwhisper.a

# Whisper model for the transcription NIF (not committed to git — 148MB)
models/ggml-base.en.bin: $(WHISPER_DIR)/Makefile
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
# $(MAKE) -C $(WHISPER_DIR) clean 
