import struct
import sys
from parsec import *

whitespace = regex(r'\s*', re.MULTILINE)
lexeme = lambda p: p << whitespace
comma = lexeme(string(','))
simple_token = lexeme(regex('[a-zA-Z0-9_]+'))

decimal_number = lexeme(regex('[0-9]+')).parsecmap(int)
hex_number = lexeme(regex('[0-9][0-9a-fA-F]*[hH]')).parsecmap(lambda z: int(z[:-1], 16))
number = hex_number ^ decimal_number
bit_spec = lexeme(string('.')) >> lexeme(decimal_number)

@lexeme
@generate
def operand():
	yield string('&')
	n = yield decimal_number
	return ('operand', n)

@generate
def mnemonic_def():
	num = yield number
	assert num == 1
	yield comma
	required_value = yield number
	yield comma
	mask = yield number
	yield comma
	mnem = yield simple_token
	args = yield sepBy(operand | simple_token, comma)
	return (required_value, mask, mnem, args)

@generate
def inc_def():
	name = yield simple_token
	yield lexeme(string('EQU'))
	yield lexeme(string('['))
	addr = yield number
	yield lexeme(string(']'))

	# there must be a nicer way to do this...
	bit = yield times(bit_spec, 0, 1)
	if bit:
		return (name, addr, bit[0])
	else:
		return (name, addr, None)


class HoltekMCU:
	def __init__(self, fmt_lines, inc_lines):
		self.mnemonics = []
		self.mem_labels = {}

		mode = None
		for line in fmt_lines:
			line = line.strip()
			if not line:
				continue
			elif line.startswith('%'):
				mode = line[1:]
			elif mode == 'mnemonic':
				self.add_mnemonic_from_str(line)
		
		for line in inc_lines:
			c = line.find(';')
			if c > -1:
				line = line[:c]
			line = line.strip()
			if not line:
				continue
			
			inc = inc_def.parse(line)
			if inc:
				name, addr, bit = inc
				key = (addr, bit)
				if key not in self.mem_labels:
					self.mem_labels[key] = name

	def add_mnemonic_from_str(self, s):
		mnem = mnemonic_def.parse(s)
		assert mnem != None
		self.mnemonics.append(mnem)

	def find_mnemonic(self, opcode):
		for mnem in self.mnemonics:
			required_value = mnem[0]
			mask = mnem[1]
			if (opcode & mask) == required_value:
				return mnem

	def process_arg(self, arg, opcode):
		if isinstance(arg, tuple) and arg[0] == 'operand':
			# for correctness, we should be parsing the 'operand'
			# strings in the fmt file
			#
			# the format for these isn't really clear, so let's just
			# wing it for now...
			if arg[1] == 1:
				# data memory
				addr = (opcode & 0x7F) | ((opcode >> 7) & 0x80)
				return self.nice_label(addr)
			elif arg[1] == 2:
				# immediate
				val = opcode & 0xFF
				return '%02Xh' % val
			elif arg[1] == 3:
				# address
				val = (opcode & 0x7FF) | ((opcode >> 3) & 0x1800)
				return '%04Xh' % val
			elif arg[1] == 4:
				# bit of data memory
				addr = (opcode & 0x7F) | ((opcode >> 7) & 0x80)
				bit = (opcode >> 7) & 7
				return self.nice_label(addr, bit)
			else:
				return 'unknown operand type %d' % arg[1]
		else:
			return arg

	def nice_label(self, addr, bit=None):
		key = (addr, bit)
		if key in self.mem_labels:
			return self.mem_labels[key]
		else:
			if bit is None:
				if addr >= 0xA0:
					return '[0%02Xh]' % addr
				else:
					return '[%02Xh]' % addr
			else:
				return '%s.%d' % (self.nice_label(addr), bit)

	def disasm(self, opcode):
		mnemonic = self.find_mnemonic(opcode)
		if not mnemonic:
			return '<<UNKNOWN>>'
		insn = mnemonic[2]
		args = [self.process_arg(arg, opcode) for arg in mnemonic[3]]
		return '%s %s' % (insn, ', '.join(args))



if __name__ == '__main__':
	if len(sys.argv) == 3:
		mcu_name = sys.argv[1]
		prog_name = sys.argv[2]

		with open('vendor-data/%s.fmt' % mcu_name, 'r') as f:
			fmt_lines = f.readlines()
		with open('vendor-data/%s.inc' % mcu_name, 'r') as f:
			inc_lines = f.readlines()

		mcu = HoltekMCU(fmt_lines, inc_lines)

		with open(prog_name, 'rb') as f:
			code = f.read()

		for address in range(0, len(code) // 2):
			opcode = struct.unpack_from('<H', code, address * 2)[0]
			print('%04x : %04x : %s' % (address, opcode, mcu.disasm(opcode)))
	else:
		print('must specify a MCU name and a program name')
		print('example: %s HT68FB560 program.bin' % sys.argv[0])

