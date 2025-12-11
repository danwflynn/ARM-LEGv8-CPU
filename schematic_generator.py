import sys
from dataclasses import dataclass, field
from typing import List, Tuple


@dataclass
class Node:
  name: str

@dataclass
class Input(Node):
  outputs: List[Tuple[str, "Node"]] = field(default_factory=list) # edge name + destination

@dataclass
class Output(Node):
  inputs: List[Tuple[str, "Node"]] = field(default_factory=list) # edge name + source

@dataclass
class Block(Input, Output):
  clocked: bool = False

class Schematic:
  def __init__(self, name: str):
    self.name: str = name
    self.inputs: List[Input] = []
    self.outputs: List[Output] = []
  
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
    stripped_line = stripped_line.rstrip()
    stripped_line = stripped_line.lstrip()
    if stripped_line.strip():
      result.append(stripped_line)
  return result

def generate_schematic(module_name):
  schematic = Schematic(module_name)

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
        # Do BFS to find everything
        for line in cleaned_lines:
          print(line)
    except FileNotFoundError:
      print(f"Error: listed file '{vfile}' does not exist.")
      sys.exit(1)


if __name__ == '__main__':
  try:
    top_module_name = sys.argv[1]
    generate_schematic(top_module_name)
  except Exception:
    print("Invalid arguments.")
