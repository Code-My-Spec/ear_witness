# LibPE.ResourceTypes



## flags/0

Generated based on documentation. Used this snipper after copy paste:

  ```
    data = ... (copy pasted)
    Enum.chunk_every(String.split(data, "
"), 5, 5, :discard) |> Enum.map(fn [_, name, id, _, desc] -> {name, Regex.replace(~r/MAKEINTRESOURCE(([0-9]+))/, id, "\1"), desc} end)
  ```