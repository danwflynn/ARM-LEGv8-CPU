import sys
from dataclasses import dataclass, field
from typing import List, Dict


@dataclass
class Node:
  name: str

@dataclass
class Input(Node):
  outputs: List["Output"] = field(default_factory=list)

@dataclass
class Output(Node):
  pass

@dataclass
class Inout(Input, Output):
  pass

@dataclass
class Wire(Input, Output):
  pass

@dataclass
class Block(Inout):
  clocked: bool = False

class Schematic:
  def __init__(self, name: str):
    self.name: str = name
    self.inputs: List[Input] = []
    self.nodes: Dict[str, Node] = {}
    self.node_visited: Dict[str, bool] = {}
  
  def connect(self, input: Input, output_name: str, node_type, clk=None):
    visited = output_name in self.nodes.keys()
    if not visited: self.nodes[output_name] = node_type(name=output_name)
    input.outputs.append(self.nodes[output_name])
    if node_type is Block: self.nodes[output_name].clocked = clk
    return visited

  def add_input(self, input: Input):
    self.inputs.append(input)
    self.nodes[input.name] = input

  def draw_schematic():
    pass


def strip_verilog(lines):
  result = []
  in_block_comment = False
  for line in lines:
    i = 0
    stripped_line = ""
    while i < len(line):
      if not in_block_comment:
        if line.startswith("/*", i):
          in_block_comment = True
          i += 2
          continue
        if line.startswith("//", i) or line.startswith("`", i):
          break
        stripped_line += line[i]
        i += 1
      else:
        if line.startswith("*/", i):
          in_block_comment = False
          i += 2
        else:
          i += 1
    stripped_line = stripped_line.strip()
    if not stripped_line:
        continue
    parts = stripped_line.split(';')
    for idx, part in enumerate(parts):
      part = part.strip()
      if not part:
        continue
      if idx < len(parts) - 1:
        result.append(part + ';')
      else:
        if stripped_line.endswith(';'):
          result.append(part + ';')
        else:
          result.append(part)
  return result


def get_submodule(module_name, lines):
  result = []
  inside_module = False
  for line in lines:
    if line.startswith("module "):
      name = ""
      for char in line[7:]:
        if char == " ": continue
        elif char == "(": break
        else: name += char
      if name == module_name: inside_module = True
    if inside_module: result.append(line)
    if "endmodule" in line and inside_module: return result
  raise ValueError(f"{module_name} module not found or not correctly instantiated.\nmodule {module_name}( must be on 1 line.")


def get_leafs_of_keyword(submodule, keyword):
  input_names = []
  input = ""
  for raw_line in submodule:
    line = raw_line
    if keyword != "reg": line = raw_line.replace(" reg ", " ").replace(" reg[", "[")
    if line.startswith(keyword):
      outside_brackets = True
      for char in line[len(keyword):]:
        if char == " ": continue
        elif char == "[": outside_brackets = False
        elif char == "]": outside_brackets = True
        elif outside_brackets and char != "," and char != ";": input += char
        elif outside_brackets and (char == "," or char == ";"):
          input_names.append(input)
          input = ""
  return input_names


def tokenize_line(line):
  tokens = []
  current_token = ""
  for char in line:
    if current_token == "" and char == " ": continue
    elif char != " " and char != "," and char != ":" and char != "?" and char != ";" and char != "&" and char != "|" and char != "+" and char != "-" and char != "*" and char != "=" and char != ".":
      current_token += char
    else:
      if current_token != "": tokens.append(current_token)
      current_token = ""
      if char != " ": tokens.append(char)
  return tokens


def bfs_from_node(all_lines, submodule, node: Input, schematic: Schematic):
  if not isinstance(node, Block):
    move_down = True
    i = 0
    while i < len(submodule):
      tokens = tokenize_line(submodule[i])
      if "(" + node.name + ")" in submodule[i].replace(" ", "") and "." in submodule[i] and node.name != "clk" and move_down:
        move_down = False
        branch_i = i
      if not move_down and "." not in tokens[0] and "(" not in tokens[0]:
        submod_inputs = get_leafs_of_keyword(get_submodule(tokens[0], all_lines), "input") + get_leafs_of_keyword(get_submodule(tokens[0], all_lines), "inout")
        clk = "clk" in submod_inputs
        port_name = ""
        reading_chars = False
        for char in submodule[branch_i]:
          if char == ".": reading_chars = True
          elif reading_chars and char != "(": port_name += char
          elif reading_chars: break
        if port_name in submod_inputs: schematic.node_visited[tokens[0]] = schematic.connect(node, tokens[0], Block, clk)
        move_down = True
        i = branch_i
      elif node.name in tokens[3:] and tokens[2] == "=" and tokens[0] == "wire": schematic.node_visited[tokens[1]] = schematic.connect(node, tokens[1], Wire)
      elif node.name in tokens[3:] and tokens[2] == "=" and tokens[0] == "assign":
        if tokens[1] in get_leafs_of_keyword(submodule, "wire"): schematic.node_visited[tokens[1]] = schematic.connect(node, tokens[1], Wire)
        elif tokens[1] in get_leafs_of_keyword(submodule, "inout"): schematic.node_visited[tokens[1]] = schematic.connect(node, tokens[1], Inout)
        elif tokens[1] in get_leafs_of_keyword(submodule, "output"): schematic.node_visited[tokens[1]] = schematic.connect(node, tokens[1], Output)
      if move_down: i += 1
      else: i -= 1
  else: # Block case
    for block_output in (get_leafs_of_keyword(get_submodule(node.name, all_lines), "output") + get_leafs_of_keyword(get_submodule(node.name, all_lines), "inout")):
      search_for_output = False
      for line in submodule:
        if len(tokenize_line(line)) > 0 and tokenize_line(line)[0] == node.name: search_for_output = True
        if search_for_output and "." + block_output in line:
          for token in tokenize_line(line):
            if token.startswith(block_output + "("):
              output_name = ""
              for char in token[len(block_output)+1:]:
                if char == ")": break
                output_name += char
              if output_name in get_leafs_of_keyword(submodule, "wire"): schematic.node_visited[output_name] = schematic.connect(node, output_name, Wire)
              elif output_name in get_leafs_of_keyword(submodule, "inout"): schematic.node_visited[output_name] = schematic.connect(node, output_name, Inout)
              elif output_name in get_leafs_of_keyword(submodule, "output"): schematic.node_visited[output_name] = schematic.connect(node, output_name, Output)
  
  for dest in node.outputs:
    print(node.name, dest, schematic.node_visited[dest.name])
    if isinstance(dest, Block) and not schematic.node_visited[dest.name]: bfs_from_node(all_lines, submodule, dest, schematic)


def generate_schematic(module_name):
  schematic = Schematic(module_name)
  all_lines = []

  try:
    with open("files.txt", "r") as f:
      verilog_files = [line.strip() for line in f if line.strip()]
  except FileNotFoundError:
    print("Error: files.txt not found.")
    sys.exit(1)
  for vfile in verilog_files:
    try:
      with open(vfile, "r") as f:
        cleaned_lines = strip_verilog(f)
        for line in cleaned_lines:
          all_lines.append(line)
    except FileNotFoundError:
      print(f"Error: listed file '{vfile}' does not exist.")
      sys.exit(1)
  
  top_module = get_submodule(module_name, all_lines)
  
  # get the inputs
  for leaf in get_leafs_of_keyword(top_module, "input"): schematic.add_input(Input(name=leaf))
  for leaf in get_leafs_of_keyword(top_module, "inout"): schematic.add_input(Inout(name=leaf))
  # search from all inputs
  for input in schematic.inputs: bfs_from_node(all_lines, top_module, input, schematic)


if __name__ == '__main__':
  top_module_name = sys.argv[1]
  generate_schematic(top_module_name)
