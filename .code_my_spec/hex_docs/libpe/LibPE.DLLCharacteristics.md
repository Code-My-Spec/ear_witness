# LibPE.DLLCharacteristics



## flags/0

Generated based on documentation. Used this snipper after copy paste:

  ```
    data = ... (copy pasted)
    Enum.chunk_every(String.split(data, "
"), 3, 3, :discard) |> Enum.map(fn [name, <<"0x",id :: binary>>, desc] -> {name, elem(Integer.parse(id, 16), 0), desc} end)
  ```