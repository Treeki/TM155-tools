# Holtek HT68FB560 8-Bit Flash USB MCU
# IDAPython Processor Module
# Developed for and tested with IDA 7.0.

# Copyright (c) Ash Wolf, 2018
# Licensed under the MIT License

# Project Home: https://github.com/Treeki/TM155-tools

from ida_bytes import *
from ida_diskio import *
from ida_enum import *
from ida_ua import *
from ida_idp import *
from ida_auto import *
from ida_nalt import *
import ida_frame
from ida_funcs import *
from ida_lines import *
from ida_problems import *
from ida_offset import *
from ida_segment import *
from ida_name import *
from ida_netnode import *
import ida_ida
import json

BANK_COUNT = 6

HTOP_NONE   = 0   # no operand
HTOP_DATA   = 1   # [m]
HTOP_DATA_A = 2   # [m],A
HTOP_A_DATA = 3   # A,[m]
HTOP_A_IMM  = 4   # A,imm
HTOP_ADDR   = 5   # program address
HTOP_BIT    = 6   # [m].i

IDEF_MAGIC_VALUE = 0
IDEF_MASK        = 1
IDEF_MNEMONIC    = 2
IDEF_OP_TYPE     = 3
IDEF_IDA_FEATURE = 4
IDEF_COMMENT     = 5

INSN_DEFS = [
	(0x0000, 0xffff, 'nop',     HTOP_NONE,   0,                       'Nothing'),
	(0x0001, 0xffff, 'clrwdt',  HTOP_NONE,   0,                       'Pre-Clear Watchdog Timer'),
	(0x0002, 0xffff, 'halt',    HTOP_NONE,   CF_STOP,                 'Enter power down mode'),
	(0x0003, 0xffff, 'ret',     HTOP_NONE,   CF_STOP,                 'Return from subroutine'),
	(0x0004, 0xffff, 'reti',    HTOP_NONE,   CF_STOP,                 'Return from interrupt'),
	(0x0005, 0xffff, 'clrwdt2', HTOP_NONE,   0,                       'Pre-Clear Watchdog Timer 2'),
	(0x0080, 0xbf80, 'mov',     HTOP_DATA_A, CF_CHG1|CF_USE2,         '[m] := A'),
	(0x0100, 0xbf80, 'cpla',    HTOP_DATA,   CF_USE1,                 'A := ~[m]'),
	(0x0180, 0xbf80, 'cpl',     HTOP_DATA,   CF_USE1|CF_CHG1,         '[m] := ~[m]'),
	(0x0200, 0xbf80, 'sub',     HTOP_A_DATA, CF_USE1|CF_CHG1|CF_USE2, 'A -= [m]'),
	(0x0280, 0xbf80, 'subm',    HTOP_A_DATA, CF_USE1|CF_USE2|CF_CHG2, '[m] := A - [m]'),
	(0x0300, 0xbf80, 'add',     HTOP_A_DATA, CF_USE1|CF_CHG1|CF_USE2, 'A += [m]'),
	(0x0380, 0xbf80, 'addm',    HTOP_A_DATA, CF_USE1|CF_USE2|CF_CHG2|CF_JUMP, '[m] += A'),
	(0x0400, 0xbf80, 'xor',     HTOP_A_DATA, CF_USE1|CF_CHG1|CF_USE2, 'A ^= [m]'),
	(0x0480, 0xbf80, 'xorm',    HTOP_A_DATA, CF_USE1|CF_USE2|CF_CHG2, '[m] ^= A'),
	(0x0500, 0xbf80, 'or',      HTOP_A_DATA, CF_USE1|CF_CHG1|CF_USE2, 'A |= [m]'),
	(0x0580, 0xbf80, 'orm',     HTOP_A_DATA, CF_USE1|CF_USE2|CF_CHG2, '[m] |= A'),
	(0x0600, 0xbf80, 'and',     HTOP_A_DATA, CF_USE1|CF_CHG1|CF_USE2, 'A &= [m]'),
	(0x0680, 0xbf80, 'andm',    HTOP_A_DATA, CF_USE1|CF_USE2|CF_CHG2, '[m] &= A'),
	(0x0700, 0xbf80, 'mov',     HTOP_A_DATA, CF_CHG1|CF_USE2,         'A := [m]'),
	(0x1000, 0xbf80, 'sza',     HTOP_DATA,   CF_USE1,                 'A := [m]; if (A == 0) skip next'),
	(0x1080, 0xbf80, 'sz',      HTOP_DATA,   CF_USE1,                 'if ([m] == 0) skip next'),
	(0x1100, 0xbf80, 'swapa',   HTOP_DATA,   CF_USE1,                 'A := swapNibbles([m])'),
	(0x1180, 0xbf80, 'swap',    HTOP_DATA,   CF_USE1|CF_CHG1,         '[m] := swapNibbles([m])'),
	(0x1200, 0xbf80, 'sbc',     HTOP_A_DATA, CF_USE1|CF_CHG1|CF_USE2, 'A ^= [m]'),
	(0x1280, 0xbf80, 'sbcm',    HTOP_A_DATA, CF_USE1|CF_USE2|CF_CHG2, '[m] ^= A'),
	(0x1300, 0xbf80, 'adc',     HTOP_A_DATA, CF_USE1|CF_CHG1|CF_USE2, 'A ^= [m]'),
	(0x1380, 0xbf80, 'adcm',    HTOP_A_DATA, CF_USE1|CF_USE2|CF_CHG2, '[m] ^= A'),
	(0x1400, 0xbf80, 'inca',    HTOP_DATA,   CF_USE1,                 'A := [m] + 1'),
	(0x1480, 0xbf80, 'inc',     HTOP_DATA,   CF_USE1|CF_CHG1,         '[m]++'),
	(0x1500, 0xbf80, 'deca',    HTOP_DATA,   CF_USE1,                 'A := [m] - 1'),
	(0x1580, 0xbf80, 'dec',     HTOP_DATA,   CF_USE1|CF_CHG1,         '[m]--'),
	(0x1600, 0xbf80, 'siza',    HTOP_DATA,   CF_USE1,                 'A := [m] + 1; if (A == 0) skip next'),
	(0x1680, 0xbf80, 'siz',     HTOP_DATA,   CF_USE1|CF_CHG1,         '[m]++; if ([m] == 0) skip next'),
	(0x1700, 0xbf80, 'sdza',    HTOP_DATA,   CF_USE1,                 'A := [m] - 1; if (A == 0) skip next'),
	(0x1780, 0xbf80, 'sdz',     HTOP_DATA,   CF_USE1|CF_CHG1,         '[m]--; if ([m] == 0) skip next'),
	(0x1800, 0xbf80, 'rla',     HTOP_DATA,   CF_USE1,                 'A := [m] rotLeft 1'),
	(0x1880, 0xbf80, 'rl',      HTOP_DATA,   CF_USE1|CF_CHG1,         '[m] rotLeft 1'),
	(0x1900, 0xbf80, 'rra',     HTOP_DATA,   CF_USE1,                 'A := [m] rotRight 1'),
	(0x1980, 0xbf80, 'rr',      HTOP_DATA,   CF_USE1|CF_CHG1,         '[m] rotRight 1'),
	(0x1a00, 0xbf80, 'rlca',    HTOP_DATA,   CF_USE1,                 'A := [m] rotLeft 1   (with carry)'),
	(0x1a80, 0xbf80, 'rlc',     HTOP_DATA,   CF_USE1|CF_CHG1,         '[m] rotLeft 1   (with carry)'),
	(0x1b00, 0xbf80, 'rrca',    HTOP_DATA,   CF_USE1,                 'A := [m] rotRight 1  (with carry)'),
	(0x1b80, 0xbf80, 'rrc',     HTOP_DATA,   CF_USE1|CF_CHG1,         '[m] rotRight 1  (with carry)'),
	(0x1d00, 0xbf80, 'tabrd',   HTOP_DATA,   CF_CHG1,                 'TBLH:[m] := program[TBHP:TBLP]'),
	(0x1e80, 0xbf80, 'daa',     HTOP_DATA,   CF_CHG1,                 '[m] = bcdAdjust(A)'),
	(0x1f00, 0xbf80, 'clr',     HTOP_DATA,   CF_USE1|CF_CHG1,         '[m] := 0'),
	(0x1f80, 0xbf80, 'set',     HTOP_DATA,   CF_USE1|CF_CHG1,         '[m] := FFh'),
	(0x0900, 0xff00, 'ret',     HTOP_A_IMM,  CF_CHG1|CF_USE2|CF_STOP, 'A := imm; return'),
	(0x0a00, 0xff00, 'sub',     HTOP_A_IMM,  CF_USE1|CF_CHG1|CF_USE2, 'A -= imm'),
	(0x0b00, 0xff00, 'add',     HTOP_A_IMM,  CF_USE1|CF_CHG1|CF_USE2, 'A += imm'),
	(0x0c00, 0xff00, 'xor',     HTOP_A_IMM,  CF_USE1|CF_CHG1|CF_USE2, 'A ^= imm'),
	(0x0d00, 0xff00, 'or',      HTOP_A_IMM,  CF_USE1|CF_CHG1|CF_USE2, 'A |= imm'),
	(0x0e00, 0xff00, 'and',     HTOP_A_IMM,  CF_USE1|CF_CHG1|CF_USE2, 'A &= imm'),
	(0x0f00, 0xff00, 'mov',     HTOP_A_IMM,  CF_CHG1|CF_USE2,         'A := imm'),
	(0x2000, 0x3800, 'call',    HTOP_ADDR,   CF_CALL|CF_USE1,         'call addr'),
	(0x2800, 0x3800, 'jmp',     HTOP_ADDR,   CF_STOP|CF_USE1,         'jump to addr'),
	(0x3000, 0xbc00, 'set',     HTOP_BIT,    CF_CHG1|CF_USE2,         '[m] := 1'),
	(0x3400, 0xbc00, 'clr',     HTOP_BIT,    CF_CHG1|CF_USE2,         '[m] := 0'),
	(0x3800, 0xbc00, 'snz',     HTOP_BIT,    CF_USE1|CF_USE2,         'if ([m] != 0) skip next'),
	(0x3c00, 0xbc00, 'sz',      HTOP_BIT,    CF_USE1|CF_USE2,         'if ([m] == 0) skip next'),
]

class NiceEnum(object):
	pass

itypes = NiceEnum()
for i, d in enumerate(INSN_DEFS):
	# choose a non-conflicting name for certain instructions
	name = 'i_' + d[IDEF_MNEMONIC]
	if d[IDEF_OP_TYPE] == HTOP_BIT:
		name += '_bit'
	elif d[IDEF_OP_TYPE] == HTOP_A_IMM:
		name += '_imm'
	setattr(itypes, name, i)


with open(get_user_idadir() + '/procs/ht68fb560.json', 'r') as f:
	REG_DEFS = json.load(f)

reg_lookup = NiceEnum()
for addr, reg in enumerate(REG_DEFS):
	if reg:
		setattr(reg_lookup, reg['name'], addr)



def get_itype_for_opcode(op):
	for i, d in enumerate(INSN_DEFS):
		magic = d[IDEF_MAGIC_VALUE]
		mask = d[IDEF_MASK]
		if (op & mask) == magic:
			return i
	return None

def get_opvalue_for_opcode(itype, op):
	idef = INSN_DEFS[itype]
	htop = idef[IDEF_OP_TYPE]
	if htop == HTOP_DATA or htop == HTOP_A_DATA or htop == HTOP_DATA_A:
		# data memory
		return (op & 0x7F) | ((op >> 7) & 0x80)
	elif htop == HTOP_A_IMM:
		# immediate
		return op & 0xFF
	elif htop == HTOP_ADDR:
		# address
		return (op & 0x7FF) | ((op >> 3) & 0x1800)
	elif htop == HTOP_BIT:
		# bit of data memory
		addr = (op & 0x7F) | ((op >> 7) & 0x80)
		bit = (op >> 7) & 7
		return (addr, bit)


def guess_jump_table_end(start):
	guaranteed_end = BADADDR
	work_ea = start

	# we want to keep going until we find something that can't
	# possibly be part of the jump table
	while is_mapped(work_ea) and work_ea != guaranteed_end:
		# what's here?
		op = get_wide_byte(work_ea)
		itype = get_itype_for_opcode(op)

		if itype == itypes.i_ret or itype == itypes.i_ret_imm:
			# ret can be part of the jump table, that's fine
			# just keep going
			work_ea += 1
		elif itype == itypes.i_jmp:
			target = get_opvalue_for_opcode(itype, op)
			if target < guaranteed_end or guaranteed_end == BADADDR:
				# we know that if we're jumping to an instruction,
				# then that's definitely _after_ the jump table
				# so we consider that to be a point where we must end
				guaranteed_end = target
			work_ea += 1
		else:
			# this is not a ret or a jump
			# so it's probably not part of the jump table
			# bail the fuck out
			break

	return work_ea - 1


class HoltekProcessor(processor_t):
	id = 0x8000 + 420

	flag = 0 # for now?

	cnbits = 16
	dnbits = 8
	segreg_size = 0
	tbyte_size = 0

	psnames = ['htkFB560']
	plnames = ['Holtek HT68FB560']

	assembler = {
		'flag': AS_COLON | AS_N2CHR,
		'uflag': 0,
		'name': 'Holtek Assembler',
		'origin': 'ORG',
		'end': 'END',
		'cmnt': '#',
		'ascsep': '"',
		'accsep': "'",
		'esccodes': '"\'',
		'a_ascii': 'DC',
		'a_byte': 'DB',
		'a_word': 'DW',
		'a_bss': 'SPACE %s',
		'a_equ': '.equ',
		'a_seg': 'seg',
		'a_curip': '$',
		'a_public': 'public',
		'a_weak': 'weak',
		'a_extrn': 'extern',
		'a_comdef': 'comm',
		'a_align': 'ALIGN',
		'lbrace': '(',
		'rbrace': ')',
		'a_mod': '%',
		'a_band': '&',
		'a_bor': '|',
		'a_xor': '^',
		'a_bnot': '~',
		'a_shl': '<<',
		'a_shr': '>>',
		'a_sizeof_fmt': 'sizeof %s',
		'low8': 'LOW %s',
		'high8': 'HIGH %s'
	}

	# we never use CS or DS but it seems like IDA expects us to
	# provide /something/ for reg_code_sreg and reg_data_sreg, so...
	# have something!
	reg_names = ['A', 'CS', 'DS']
	reg_first_sreg = 1
	reg_last_sreg = 2
	reg_code_sreg = 1
	reg_data_sreg = 2

	# the start 'itype' (arbitrary instruction type ID) we expose
	# we generate instruc (list) and instruc_end (last itype) in __init__
	instruc_start = 0


	def __init__(self):
		processor_t.__init__(self)

		self.instruc = []
		for insn in INSN_DEFS:
			self.instruc.append({'name': insn[IDEF_MNEMONIC], 'feature': insn[IDEF_IDA_FEATURE]})
		self.instruc_end = len(INSN_DEFS)
		self.icode_return = 3   # ret. We should dynamically compute this index, really


	def _ensure_ram_segment_exists(self):
		segm = get_segm_by_name('HTRAM')
		if segm:
			self.ram_addr = segm.start_ea
		else:
			# alright, we want to create our RAM segment
			# find some space to do that in
			ram_size = 0x100 * BANK_COUNT
			ram_start = free_chunk(1, ram_size, -0xF)
			ram_end = ram_start + ram_size
			segm = add_segm_ex(ram_start, ram_end, ram_start >> 4, 0, saAbs, scPriv, ADDSEG_NOSREG)
			set_segm_name(ram_start, 'HTRAM')
			set_segm_type(ram_start, SEG_IMEM)
			self.ram_addr = ram_start

			self._prepare_db()


	def _prepare_db(self):
		# define some enums
		bit_enums = {}
		for addr, reg in enumerate(REG_DEFS):
			if reg and 'bits' in reg:
				prefix = str(reg['name']) + ':'
				enum = add_enum(BADADDR, 'bit_' + str(reg['name']), 0)
				bit_enums[addr] = enum
				for bit, name in enumerate(reg['bits']):
					if name:
						add_enum_member(enum, prefix + str(name), bit, DEFMASK)

		# fill all the register info in
		for bank in range(6):
			prefix = 'B%d:' % bank
			for offset, reg in enumerate(REG_DEFS):
				if reg and ('banks' not in reg or bank in reg['banks']):
					ea = self.ram_addr + (bank * 0x100) + offset
					MakeByte(ea)
					MakeName(ea, prefix + str(reg['name']))
					set_cmt(ea, str(reg['comment']), True)

					if offset in bit_enums:
						self.helper.altset_ea(ea, bit_enums[offset], self.bitfield_enum_tag)

		# name the interrupts
		MakeName(0, 'ResetVector')
		MakeName(4, 'Interrupt_INT0_Pin')
		MakeName(8, 'Interrupt_INT1_Pin')
		MakeName(0xC, 'Interrupt_USB')
		MakeName(0x10, 'Interrupt_MFunct0')
		MakeName(0x14, 'Interrupt_MFunct1')
		MakeName(0x18, 'Interrupt_MFunct2')
		MakeName(0x1C, 'Interrupt_MFunct3')
		MakeName(0x20, 'Interrupt_SIM')
		MakeName(0x24, 'Interrupt_SPIA')
		MakeName(0x28, 'Interrupt_LVD')


	def notify_init(self, idp_file):
		self.helper = netnode()
		self.helper.create('$ holtek')
		self.bitfield_enum_tag = 'b'


	def notify_newfile(self, fname):
		print('NewFile: %s' % fname)
		self._ensure_ram_segment_exists()


	def notify_oldfile(self, fname):
		print('OldFile: %s' % fname)
		self._ensure_ram_segment_exists()


	def notify_ana(self, insn):
		# Decode this instruction
		opcode = get_wide_byte(insn.ea)
		insn.size = 1

		itype = get_itype_for_opcode(opcode)
		if itype is None:
			return 0

		idef = INSN_DEFS[itype]
		htop = idef[IDEF_OP_TYPE]

		# load A into Op1 for certain instructions
		if htop == HTOP_A_DATA or htop == HTOP_A_IMM:
			insn.Op1.type = o_reg
			insn.Op1.dtype = dt_byte
			insn.Op1.reg = 0

		# load A into Op2 for [m],A
		if htop == HTOP_DATA_A:
			insn.Op2.type = o_reg
			insn.Op2.dtype = dt_byte
			insn.Op2.reg = 0

		# load [m] into Op1 for [m] and [m],A
		if htop == HTOP_DATA or htop == HTOP_DATA_A:
			insn.Op1.type = o_mem
			insn.Op1.dtype = dt_byte
			insn.Op1.addr = self.ram_addr + get_opvalue_for_opcode(itype, opcode)

		# load [m] into Op2 for A,[m]
		if htop == HTOP_A_DATA:
			insn.Op2.type = o_mem
			insn.Op2.dtype = dt_byte
			insn.Op2.addr = self.ram_addr + get_opvalue_for_opcode(itype, opcode)

		# other cases!
		if htop == HTOP_A_IMM:
			insn.Op2.type = o_imm
			insn.Op2.dtype = dt_byte
			insn.Op2.value = get_opvalue_for_opcode(itype, opcode)
		elif htop == HTOP_ADDR:
			insn.Op1.type = o_near
			insn.Op1.dtype = dt_byte
			insn.Op1.addr = get_opvalue_for_opcode(itype, opcode)
		elif htop == HTOP_BIT:
			addr, bit = get_opvalue_for_opcode(itype, opcode)
			insn.Op1.type = o_mem
			insn.Op1.dtype = dt_byte
			insn.Op1.addr = self.ram_addr + addr
			insn.Op2.type = o_imm
			insn.Op2.dtype = dt_byte
			insn.Op2.value = bit

		insn.itype = itype
		return 1


	def _create_addm_pcl_jump_table(self, insn):
		# this is a jump into a jump table, starting right after!
		# determine how big it is
		jt_start = insn.ea + 1
		jt_end = guess_jump_table_end(jt_start)

		named_targets = {}

		for entry_ea in xrange(jt_start, jt_end + 1):
			entry_index = entry_ea - jt_start
			add_cref(insn.ea, entry_ea, fl_JN)
			MakeName(entry_ea, 'jtbl_%04X_case_%02X' % (insn.ea, entry_index))

			# diversion: if the jump is itself a branch, then we should
			# name its target, too!
			entry_op = get_wide_byte(entry_ea)
			entry_itype = get_itype_for_opcode(entry_op)
			if entry_itype == itypes.i_jmp:
				jt_target = get_opvalue_for_opcode(entry_itype, entry_op)
				try:
					named_targets[jt_target].append(entry_index)
				except KeyError:
					named_targets[jt_target] = [entry_index]

		# now apply the names for named targets, if we saw any
		for target, index_list in named_targets.iteritems():
			index_strs = '_'.join(['%02X' % i for i in index_list])
			MakeName(target, 'jtbl_%04X_case_target_%s' % (insn.ea, index_strs))


	def _poke_operand(self, insn, op, read_flag, write_flag):
		if op.type == o_mem:
			if read_flag != 0:
				add_dref(insn.ea, op.addr, dr_R)
			if write_flag != 0:
				add_dref(insn.ea, op.addr, dr_W)

		if op.type == o_imm and INSN_DEFS[insn.itype][IDEF_OP_TYPE] == HTOP_BIT:
			# make this an enum, if we can
			# TODO: ignore some like ACC maybe?
			# maybe also make sure we don't overwrite existing op_enums
			bit = op.value
			enum_addr = insn.Op1.addr
			enum_id = self.helper.altval_ea(enum_addr, self.bitfield_enum_tag)
			if enum_id == 0:
				enum_id = add_enum(BADADDR, 'bit_%03X' % (enum_addr - self.ram_addr), 0)
				self.helper.altset_ea(enum_addr, enum_id, self.bitfield_enum_tag)
			member_id = get_enum_member(enum_id, bit, 0, DEFMASK)
			if member_id == BADADDR:
				add_enum_member(enum_id, 'b%03X:%d' % (enum_addr - self.ram_addr, bit), bit, DEFMASK)
			op_enum(insn.ea, 1, enum_id, 0)


	SKIP_ITYPES = set((itypes.i_sza, itypes.i_sz, itypes.i_siza, itypes.i_siz, itypes.i_sdza, itypes.i_sdz, itypes.i_snz_bit, itypes.i_sz_bit))

	def notify_emu(self, insn):
		itype = insn.itype
		feature = insn.get_canon_feature()

		# for most instructions, we want to chain onto the next
		flow = (feature & CF_STOP) == 0

		if itype == itypes.i_jmp:
			dest = get_opvalue_for_opcode(itype, get_wide_byte(insn.ea))
			add_cref(insn.ea, dest, fl_JN)
			flow = False
		elif itype == itypes.i_call:
			dest = get_opvalue_for_opcode(itype, get_wide_byte(insn.ea))
			add_cref(insn.ea, dest, fl_CN)

		self._poke_operand(insn, insn.Op1, feature & CF_USE1, feature & CF_CHG1)
		self._poke_operand(insn, insn.Op2, feature & CF_USE2, feature & CF_CHG2)

		if itype == itypes.i_addm:
			pcl = self.ram_addr + reg_lookup.PCL
			if insn.Op2.addr == pcl:
				self._create_addm_pcl_jump_table(insn)
				# no flow necessary as the jump table creates a bunch
				# of its own coderefs
				flow = False

		if flow:
			add_cref(insn.ea, insn.ea + 1, fl_F)
		if itype in self.SKIP_ITYPES:
			add_cref(insn.ea, insn.ea + 2, fl_JN)

		return 1

	def notify_out_operand(self, ctx, op):
		optype = op.type
		if optype == o_reg:
			ctx.out_register('A')
		elif optype == o_imm:
			ctx.out_value(op)
		elif optype == o_mem:
			r = ctx.out_name_expr(op, op.addr, BADADDR)
			if not r:
				ctx.out_tagon(COLOR_ERROR)
				ctx.out_btoa(op.addr, 16)
				ctx.out_tagoff(COLOR_ERROR)
				remember_problem(PR_NONAME, ctx.insn.ea)
		elif optype == o_near:
			r = ctx.out_name_expr(op, op.addr, BADADDR)
			if not r:
				ctx.out_tagon(COLOR_ERROR)
				ctx.out_btoa(op.addr, 16)
				ctx.out_tagoff(COLOR_ERROR)
				remember_problem(PR_NONAME, ctx.insn.ea)
		else:
			return -1

		return 1

	def notify_out_insn(self, ctx):
		insn = ctx.insn
		ctx.out_mnem()
		if INSN_DEFS[insn.itype][IDEF_OP_TYPE] == HTOP_BIT:
			ctx.out_one_operand(0)
			ctx.out_symbol('.')
			ctx.out_one_operand(1)
		else:
			for i in xrange(0, 2):
				op = ctx.insn[i]
				if op.type != o_void:
					if i > 0:
						ctx.out_symbol(',')
						ctx.out_char(' ')
					ctx.out_one_operand(i)
		ctx.set_gen_cmt()
		ctx.flush_outbuf()


	def notify_get_autocmt(self, insn):
		return INSN_DEFS[insn.itype][IDEF_COMMENT]


def PROCESSOR_ENTRY():
	return HoltekProcessor()
