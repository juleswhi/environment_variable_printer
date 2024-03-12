import argv
import envoy
import gleam/io
import gleam/result

pub fn main() {
    case argv.load().arguments {
        ["get", name] -> get(name)
        _ -> io.println("Usage: environment_variable_printer get <name>")
    }
}

pub fn get(name: String) -> Nil {
    let value = envoy.get(name)
        |> result.unwrap("")
    io.println(format_pair(name, value))
}

pub fn format_pair(name: String, value: String) -> String {
    name <> "=" <> value
}
