import sys
from dataclasses import dataclass, field
from typing import List, Tuple


@dataclass
class Node:
  name: str

@dataclass
class Input(Node):
  outputs: List[Tuple[str, "Output"]] = field(default_factory=list) # edge name + destination

@dataclass
class Output(Node):
  pass

@dataclass
class Inout(Input, Output):
  pass

@dataclass
class Block(Inout):
  clocked: bool = False

class Schematic:
  def __init__(self, name: str):
    self.name: str = name
    self.inputs: List[Input] = []
  
  def connect(input: Input, output: Output, wire: str):
    input.outputs.append((wire, output))

  def add_input(self, input: Input):
    self.inputs.append(input)

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

def get_subset(module_name, lines):
  result = []
  inside_module = False
  for line in lines:
    if "module " in line and module_name in line: inside_module = True
    if inside_module: result.append(line)
    if "endmodule" in line and inside_module: return result

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
  
  for line in get_subset(module_name, all_lines):
    print(line)


if __name__ == '__main__':
  top_module_name = sys.argv[1]
  generate_schematic(top_module_name)
