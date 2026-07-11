# Ortex.Model

A model for running Ortex inference with.

Implements a human-readable representation of a model including the name, dimension, and
type of each input and output

```
#Ortex.Model<
inputs: [{"x", "Int32", [nil, 100]}, {"y", "Float32", [nil, 100]}]
outputs: [
  {"9", "Float32", [nil, 10]},
  {"onnx::Add_7", "Float32", [nil, 10]},
  {"onnx::Add_8", "Float32", [nil, 10]}
]>
```

`nil` values represent dynamic dimensions