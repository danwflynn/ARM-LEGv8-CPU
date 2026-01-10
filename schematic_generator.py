import sys
from dataclasses import dataclass, field
from typing import List, Dict, Union
from graphviz import Digraph


@dataclass
class Gate:
  name: str

@dataclass
class SingleInputGate(Gate):
  input: Union[str, Gate]

@dataclass
class MultiInputGate(Gate):
  inputs: List[Union[str, Gate]] = field(default_factory=list)

@dataclass
class TSB(SingleInputGate):
  enable: Union[str, Gate]

@dataclass
class Node:
  name: str

@dataclass
class Input(Node):
  outputs: List[Node] = field(default_factory=list)

@dataclass
class Wire(Input):
  gate: Gate = None

@dataclass
class Output(Wire):
  pass

@dataclass
class Inout(Output):
  pass

@dataclass
class Block(Inout):
  clocked: bool = False
  input_nums: List[str] = field(default_factory=list)
  module_name: str = None

@dataclass
class Reg(Wire):
  pass


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
  if current_token != "": tokens.append(current_token)
  return tokens


def build_gate(raw_tokens: List[str]):
  not_the_gate = False
  tokens = [t.strip() for t in raw_tokens]
  while (tokens[0].startswith('(') and tokens[-1].endswith(')')) or (tokens[0].startswith('~(') and tokens[-1].endswith(')')):
    if tokens[0].startswith('(') and tokens[-1].endswith(')'):
      tokens[0] = tokens[0][1:]
      tokens[-1] = tokens[-1][:-1]
      tokens = [item for item in tokens if item]
    else:
      not_the_gate = True
      tokens[0] = tokens[0][1:]
  groups = []
  group_element = ""
  parenthesis_level = 0
  for idx, raw_token in enumerate(tokens):
    token = raw_token
    if token.count('(') == token.count(')'): token = raw_token.replace('(', "").replace(')', "")
    group_element += f"{token}"
    parenthesis_level += (token.count('(') - token.count(')'))
    if parenthesis_level == 0:
      groups.append(group_element)
      group_element = ""
    elif idx < len(tokens) - 1 and (token != tokens[idx+1] or len(token) != 1) and not token.endswith('('): group_element += " "
  
  return_gate = None
  for idx, ele in enumerate(groups):
    if len(ele) == 1 and ele == groups[idx-1]: groups.pop(idx)
  gate_chars = set([ele for ele in groups if len(ele) == 1])
  #TSB case
  if len(groups) > 4 and groups[1] == '?' and groups[3] == ':' and '\'' in groups[4] and 'z' in groups[4].lower() and groups[4][0].isdigit():
    input_field = None
    if '(' not in groups[0] and ')' not in groups[0]: input_field = groups[0]
    else: input_field = build_gate(tokenize_line(groups[0]))
    enable_field = None
    if '(' not in groups[2] and ')' not in groups[2]: enable_field = groups[2]
    else: enable_field = build_gate(tokenize_line(groups[2]))
    return_gate = TSB(name="Tri-State Buffer", input=input_field, enable=enable_field)
  elif len(gate_chars) != 1: raise ValueError(f"Groups: {groups}\nRaw tokens: {raw_tokens}\nTokens: {tokens}\nNot: {not_the_gate}\nI was too lazy to implement operator precedence. Please use parenthesis to indicate order of operations. This error could also hit if there is no logic gate operator.")
  else:
    return_gate = MultiInputGate(name=next(iter(gate_chars)))
    for group in groups:
      if group == next(iter(gate_chars)):
        continue
      if '(' in group and ')' in group:
        return_gate.inputs.append(build_gate(tokenize_line(group)))
      else:
        appending_input = group
        if group[0] == '~': appending_input = SingleInputGate(name='~', input=group[1:])
        return_gate.inputs.append(appending_input)
  
  if not_the_gate: return SingleInputGate(name='~', input=return_gate)
  else: return return_gate


class Schematic:
  def __init__(self, name: str):
    self.name: str = name
    self.inputs: List[Input] = []
    self.nodes: Dict[str, Node] = {}
    self.node_visited: Dict[str, bool] = {}
    self.gate_nodes: Dict[str, List[str]] = {}
  
  def connect(self, input: Input, output_name: str, node_type, clk=None, line=None, module_name=None):
    visited = output_name in self.nodes.keys()
    if not visited: self.nodes[output_name] = node_type(name=output_name)
    input.outputs.append(self.nodes[output_name])
    if node_type is Block:
      self.nodes[output_name].clocked = clk
      self.nodes[output_name].module_name = module_name
    if line is not None and len(tokenize_line(line)) > 5: self.nodes[output_name].gate = build_gate(tokenize_line(line)[3:-1])
    return visited

  def add_input(self, input: Input):
    self.inputs.append(input)
    self.nodes[input.name] = input
  
  def input_to_block(self, dot: Digraph, start_name: str, input: Input):
    if type(input) == Output: dot.node(f'outputof/{input.name}', style='invis')
    if len(input.outputs) > 1:
      dot.node(f'junctionof/{input.name}', shape='point', width='0.01')
      dot.edge(start_name, f'junctionof/{input.name}', label=input.name, arrowhead='none')
      if type(input) == Output: dot.edge(f'junctionof/{input.name}', f'outputof/{input.name}', label=input.name)
      for output in input.outputs:
        if isinstance(output, Block) or isinstance(output, Reg): dot.edge(f'junctionof/{input.name}', output.name)
        elif isinstance(output, Wire) and output.gate is not None:
          for gate_node in self.gate_nodes[input.name]: dot.edge(f'junctionof/{input.name}', gate_node)
        else: self.input_to_block(dot, f'junctionof/{input.name}', output)
    elif len(input.outputs) == 1:
      if isinstance(input.outputs[0], Block) or isinstance(input.outputs[0], Reg):
        if type(input) == Output: 
          dot.node(f'connectof/{input.name}', shape='point', width='0.01')
          dot.edge(start_name, f'connectof/{input.name}', label=input.name, arrowhead='none')
          dot.edge(f'connectof/{input.name}', f'outputof/{input.name}', label=input.name)
          dot.edge(f'connectof/{input.name}', input.outputs[0].name, label=input.name)
        else: dot.edge(start_name, input.outputs[0].name, label=input.name)
      elif isinstance(input.outputs[0], Wire) and input.outputs[0].gate is not None:
        if type(input) == Output: 
          dot.node(f'connectof/{input.name}', shape='point', width='0.01')
          dot.edge(start_name, f'connectof/{input.name}', label=input.name, arrowhead='none')
          dot.edge(f'connectof/{input.name}', f'outputof/{input.name}', label=input.name)
          for gate_node in self.gate_nodes[input.name]: dot.edge(f'connectof/{input.name}', gate_node, label=input.name)
        else: 
          for gate_node in self.gate_nodes[input.name]: dot.edge(start_name, gate_node, label=input.name)
      else:
        dot.node(f'connectof/{input.name}', shape='point', width='0.01')
        dot.edge(start_name, f'connectof/{input.name}', label=input.name, arrowhead='none')
        if type(input) == Output: dot.edge(f'connectof/{input.name}', f'outputof/{input.name}', label=input.name)
        self.input_to_block(dot, f'connectof/{input.name}', input.outputs[0])

  def gate_level_up(self, dot: Digraph, gate_name_below: str, current_level_content: Union[str, Gate], level: int, wire_name: str):
    if isinstance(current_level_content, Gate):
      dot.node(f'gatelevel{level}/{wire_name}/{current_level_content.name}', current_level_content.name)
      dot.edge(f'gatelevel{level}/{wire_name}/{current_level_content.name}', gate_name_below)
      if type(current_level_content) == SingleInputGate: self.gate_level_up(dot, f'gatelevel{level}/{wire_name}/{current_level_content.name}', current_level_content.input, level+1, wire_name)
      elif type(current_level_content) == TSB:
        self.gate_level_up(dot, f'gatelevel{level}/{wire_name}/{current_level_content.name}', current_level_content.input, level+1, wire_name)
        self.gate_level_up(dot, f'gatelevel{level}/{wire_name}/{current_level_content.name}', current_level_content.enable, level+1, wire_name)
      elif type(current_level_content) == MultiInputGate:
        for gate_input in current_level_content.inputs: self.gate_level_up(dot, f'gatelevel{level}/{wire_name}/{current_level_content.name}', gate_input, level+1, wire_name)
    else:
      if current_level_content not in self.gate_nodes.keys(): self.gate_nodes[current_level_content] = [gate_name_below]
      else: self.gate_nodes[current_level_content].append(gate_name_below)

  def draw_schematic(self):
    dot = Digraph(graph_attr={'rankdir': 'LR'}, node_attr={'shape': 'box'})

    blocks = [n for n in self.nodes.values() if isinstance(n, Block)]
    regs = [n for n in self.nodes.values() if isinstance(n, Reg)]
    gated_wires = [n for n in self.nodes.values() if isinstance(n, Wire) and not isinstance(n, Block) and not isinstance(n, Reg) and n.gate is not None]
    for block in blocks: dot.node(block.name, block.module_name)
    for reg in regs: dot.node(reg.name)
    for wire in gated_wires:
      dot.node(f'gatelevel0/{wire.name}/{wire.gate.name}', wire.gate.name)
      if type(wire.gate) == SingleInputGate: self.gate_level_up(dot, f'gatelevel0/{wire.name}/{wire.gate.name}', wire.gate.input, 1, wire.name)
      elif type(wire.gate) == TSB:
        self.gate_level_up(dot, f'gatelevel0/{wire.name}/{wire.gate.name}', wire.gate.input, 1, wire.name)
        self.gate_level_up(dot, f'gatelevel0/{wire.name}/{wire.gate.name}', wire.gate.enable, 1, wire.name)
      elif type(wire.gate) == MultiInputGate:
        for gate_input in wire.gate.inputs: self.gate_level_up(dot, f'gatelevel0/{wire.name}/{wire.gate.name}', gate_input, 1, wire.name)
      if len(wire.outputs) > 1:
        dot.node(f'junctionof/{wire.name}', shape='point', width='0.01')
        dot.edge(f'gatelevel0/{wire.name}/{wire.gate.name}', f'junctionof/{wire.name}', label=wire.name, arrowhead='none')
        for output in wire.outputs:
          if isinstance(output, Block) or isinstance(output, Reg): dot.edge(f'junctionof/{wire.name}', output.name)
          elif isinstance(output, Wire) and output.gate is not None:
            for gate_node in self.gate_nodes[wire.name]: dot.edge(f'junctionof/{wire.name}', gate_node)
          else: self.input_to_block(dot, f'junctionof/{wire.name}', output)
      elif len(wire.outputs) == 1:
        if isinstance(wire.outputs[0], Block) or isinstance(wire.outputs[0], Reg): dot.edge(f'gatelevel0/{wire.name}/{wire.gate.name}', wire.outputs[0].name, label=wire.name)
        elif isinstance(wire.outputs[0], Wire) and wire.outputs[0].gate is not None:
          for gate_node in self.gate_nodes[wire.name]: dot.edge(f'gatelevel0/{wire.name}/{wire.gate.name}', gate_node)
        else:
          dot.node(f'connectof/{wire.name}', shape='point', width='0.01')
          dot.edge(f'gatelevel0/{wire.name}/{wire.gate.name}', f'connectof/{wire.name}', label=wire.name, arrowhead='none')
          self.input_to_block(dot, f'connectof/{wire.name}', wire.outputs[0])
    for input in self.inputs:
      dot.node(f'inputof/{input.name}', style='invis')
      if len(input.outputs) > 1:
        dot.node(f'junctionof/{input.name}', shape='point', width='0.01')
        dot.edge(f'inputof/{input.name}', f'junctionof/{input.name}', label=input.name, arrowhead='none')
        for output in input.outputs:
          if isinstance(output, Block) or isinstance(output, Reg): dot.edge(f'junctionof/{input.name}', output.name)
          elif isinstance(output, Wire) and output.gate is not None:
            for gate_node in self.gate_nodes[input.name]: dot.edge(f'junctionof/{input.name}', gate_node)
          else: self.input_to_block(dot, f'junctionof/{input.name}', output)
      elif len(input.outputs) == 1:
        if isinstance(input.outputs[0], Block) or isinstance(input.outputs[0], Reg): dot.edge(f'inputof/{input.name}', input.outputs[0].name, label=input.name)
        elif isinstance(input.outputs[0], Wire) and input.outputs[0].gate is not None:
          for gate_node in self.gate_nodes[input.name]: dot.edge(f'inputof/{input.name}', self.gate_nodes[input.name])
        else:
          dot.node(f'connectof/{input.name}', shape='point', width='0.01')
          dot.edge(f'inputof/{input.name}', f'connectof/{input.name}', label=input.name, arrowhead='none')
          self.input_to_block(dot, f'connectof/{input.name}', input.outputs[0])
    for block in blocks + regs:
      for output in block.outputs:
        self.input_to_block(dot, block.name, output)
    
    dot.render(self.name, format='png', cleanup=True)


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


def dfs_from_node(all_lines, submodule, node: Input, schematic: Schematic):
  if not isinstance(node, Block):
    move_down = True
    i = 0
    while i < len(submodule):
      tokens = tokenize_line(submodule[i])

      total_line = ""
      j = i
      while j < len(submodule):
        total_line += submodule[j]
        if submodule[j].rstrip().endswith(";"): break
        else: total_line += " "
        j += 1
      big_tokens = tokenize_line(total_line)
      
      if "(" + node.name + ")" in submodule[i].replace(" ", "") and "." in submodule[i] and node.name != "clk" and move_down:
        move_down = False
        branch_i = i
      if not move_down and "." not in tokens[0] and "(" not in tokens[0]:
        submod_inputs = get_leafs_of_keyword(get_submodule(tokens[0], all_lines), "input") + get_leafs_of_keyword(get_submodule(tokens[0], all_lines), "inout")
        clk = "clk" in submod_inputs
        port_name = ""
        in_name = ""
        reading_chars_port = False
        reading_chars_in = False
        for char in submodule[branch_i]:
          if char == ".": reading_chars_port = True
          elif reading_chars_port and char != "(": port_name += char
          elif reading_chars_port:
            reading_chars_port = False
            reading_chars_in = True
            continue
          if reading_chars_in and char != ")": in_name += char
          elif reading_chars_in:
            if in_name == node.name: break
            else:
              port_name = ""
              in_name = ""
              reading_chars_in = False
        if port_name in submod_inputs: schematic.node_visited[tokens[1].replace("(", "")] = schematic.connect(node, tokens[1].replace("(", ""), Block, clk=clk, module_name=tokens[0])
        move_down = True
        i = branch_i
      elif node.name in [t.replace("(", "").replace(")", "").replace("~", "") for t in big_tokens[3:]] and big_tokens[2] == "=" and big_tokens[0] == "wire": schematic.node_visited[big_tokens[1]] = schematic.connect(node, big_tokens[1], Wire)
      elif node.name in [t.replace("(", "").replace(")", "").replace("~", "") for t in big_tokens[3:]] and big_tokens[2] == "=" and big_tokens[0] == "assign":
        if big_tokens[1] in get_leafs_of_keyword(submodule, "wire"): schematic.node_visited[big_tokens[1]] = schematic.connect(node, big_tokens[1], Wire, line=total_line)
        elif big_tokens[1] in get_leafs_of_keyword(submodule, "inout"): schematic.node_visited[big_tokens[1]] = schematic.connect(node, big_tokens[1], Inout, line=total_line)
        elif big_tokens[1] in get_leafs_of_keyword(submodule, "output"): schematic.node_visited[big_tokens[1]] = schematic.connect(node, big_tokens[1], Output, line=total_line)
      elif node.name in [t.replace("(", "").replace(")", "").replace("~", "") for t in big_tokens[3:]] and big_tokens[2] == "=" and big_tokens[1] == "<":
        if big_tokens[0] in get_leafs_of_keyword(submodule, "reg"): schematic.node_visited[big_tokens[0]] = schematic.connect(node, big_tokens[0], Reg, line=total_line)
      if move_down: i += 1
      else: i -= 1
  else: # Block case
    for block_output in (get_leafs_of_keyword(get_submodule(node.module_name, all_lines), "output") + get_leafs_of_keyword(get_submodule(node.module_name, all_lines), "inout")):
      search_for_output = False
      for line in submodule:
        if len(tokenize_line(line)) > 1 and tokenize_line(line)[1].replace("(", "") == node.name: search_for_output = True

        if search_for_output:
          search_for_num = False
          num_in = ""
          for idx, char in enumerate(line.replace(" ", "")):
            if char == '(' and line.replace(" ", "")[idx+1].isdigit():
              search_for_num = True
              continue
            if search_for_num and char != ')': num_in += char
            elif search_for_num:
              search_for_num = False
              node.input_nums.append(num_in)
              num_in = ""

        if search_for_output and "." + block_output + "(" in line:
          for token in tokenize_line(line):
            if token.startswith(block_output + "("):
              output_name = ""
              for char in token[len(block_output)+1:]:
                if char == ")": break
                output_name += char
              if output_name in get_leafs_of_keyword(submodule, "wire"): schematic.node_visited[output_name] = schematic.connect(node, output_name, Wire)
              elif output_name in get_leafs_of_keyword(submodule, "inout"): schematic.node_visited[output_name] = schematic.connect(node, output_name, Inout)
              elif output_name in get_leafs_of_keyword(submodule, "output"): schematic.node_visited[output_name] = schematic.connect(node, output_name, Output)
        if search_for_output and line.rstrip().endswith(");"): search_for_output = False
  
  for dest in node.outputs:
    if isinstance(dest, Input) and not schematic.node_visited[dest.name]: dfs_from_node(all_lines, submodule, dest, schematic)


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
  for input in schematic.inputs: dfs_from_node(all_lines, top_module, input, schematic)
  for node in schematic.nodes.values():
    if isinstance(node, Block): print(node.module_name, node.name, [o.name for o in node.outputs], node.input_nums)
    elif isinstance(node, Wire): print(node.name, [o.name for o in node.outputs], node.gate)
    else: print(node.name, [o.name for o in node.outputs])
  
  schematic.draw_schematic()


if __name__ == '__main__':
  top_module_name = sys.argv[1]
  generate_schematic(top_module_name)
