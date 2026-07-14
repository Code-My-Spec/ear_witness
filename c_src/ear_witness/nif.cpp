#include <erl_nif.h>

#include <string>
#include <iostream>
#include <vector>

extern const std::string do_transcribe_files(std::vector<std::string> file_names, std::string model_path);

static ERL_NIF_TERM transcribe_files(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  // argv[0]: list of audio file-path binaries. argv[1]: the active model
  // path (a binary; empty means "use the bundled base fallback" — resolved
  // in do_transcribe_files).
  if (argc != 2 || !enif_is_list(env, argv[0]))
  {
    return enif_make_badarg(env);
  }

  std::vector<std::string> file_names;
  ERL_NIF_TERM list = argv[0];
  ERL_NIF_TERM head, tail;

  while (enif_get_list_cell(env, list, &head, &tail))
  {
    ErlNifBinary file_name_bin;
    if (!enif_inspect_binary(env, head, &file_name_bin))
    {
      return enif_make_badarg(env);
    }

    std::string file_name((char *)file_name_bin.data, file_name_bin.size);
    file_names.push_back(file_name);

    list = tail;
  }

  ErlNifBinary model_bin;
  if (!enif_inspect_binary(env, argv[1], &model_bin))
  {
    return enif_make_badarg(env);
  }
  std::string model_path((char *)model_bin.data, model_bin.size);

  const std::string response = do_transcribe_files(file_names, model_path);

  return enif_make_string(env, response.c_str(), ERL_NIF_LATIN1);
}

// Whisper inference runs for minutes; on a normal scheduler thread that
// stalls the VM (GUI, capture timers, everything). Dirty CPU keeps it off
// the normal schedulers.
static ErlNifFunc nif_funcs[] = {
    {"transcribe_files", 2, transcribe_files, ERL_NIF_DIRTY_JOB_CPU_BOUND}};

ERL_NIF_INIT(Elixir.EarWitness.Transcribe, nif_funcs, NULL, NULL, NULL, NULL)