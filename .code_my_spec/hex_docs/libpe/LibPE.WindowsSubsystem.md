# LibPE.WindowsSubsystem



## flags/0

Generated based on documentation. Used this snipper after copy paste:

  ```
    data = ... (copy pasted)
    Enum.chunk_every(String.split(data, "
"), 3, 3, :discard) |> Enum.map(fn [name, id, desc] -> {name, String.to_integer(id), desc} end)
  ```