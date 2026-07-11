# LibPE.Codepage



## flags/0

Generated based on documentation. Used this snipper after copy paste:

  ```
    data = ... (copy pasted)
    String.split(data, "
") |> Enum.map(fn str -> String.split(str, " ", parts: 3, trim: true) end) |> Enum.filter(fn x -> length(x) == 3 end) |> Enum.map(fn [id, name, desc] -> {name, String.to_integer(id), desc} end)
  ```