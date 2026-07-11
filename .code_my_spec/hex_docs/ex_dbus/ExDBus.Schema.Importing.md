# ExDBus.Schema.Importing

Importing other schemas:

- Importing interfaces.
Inside a <node> definition, it is possible to import
nodes and interfaces from other schemas, using the `import from()` syntax:

1. Importing all root node children of nodes and interfaces from another schema
`import from(Module)` - alias of `import from(Module), path: "/"`
2. Importing all nodes and interfaces under a given path, from another Schema:
`import from(Module), path: "/"` - imports all under the root node.
`import from(Module), path: "/Child"` - imports from Module schema,
  all nodes and interfaces inside the node named `/Child` that is a
  a child of the root node.
`import from(Module), path: "/Child/Level2Child"` - imports from Module schema,
  all nodes and interfaces inside the node named `/Level2Child`
  root (/)
    -- Child
      -- Level2Child
        -- (nodes and interfaces that are imported)
3. Importing specific interfaces and nodes from a given Module schema:

Imports the `org.example.InterfaceName` defined in the root (`/`) node of
Module schema.
```
import from(Module) do
  interface("org.example.InterfaceName")
end
```

Imports the `org.example.InterfaceName` defined in the node named `/Child`
of the Module schema.
```
import from(Module) do
  interface("org.example.InterfaceName"), path: "/Child"
end
```
can also be written as
```
import from(Module), path: "/Child" do
  interface("org.example.InterfaceName")
end
```

4. Import aliasing
An import can be aliased - available only in the block syntax.
```
import from(Module) do
  interface("org.example.InterfaceName"), as: "org.example.RenamedInterface"
end
```

CAVEAT:
Importing requires interfaces to define the following with public functions:
- method `callback()`
- property `setter()` and property `getter()`

Using private functions in a schema that is to be imported,
will fail in the importing schema.

TODO: Implement references, to preserve private functions
{:reference, name, {schema, path, {:object, object_name}}}
{:reference, name, {schema, path, {:interface, interface_name}}}