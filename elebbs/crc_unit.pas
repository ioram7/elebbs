unit Crc_Unit;
(*
**
** Copyright (C) 1999-2003 Maarten Bekers. All rights reserved.
**
** This file is part of EleBBS, EleXer and EleWEB.
**
** This file may be distributed under the terms of the Q Public License
** as defined by Trolltech AS of Norway and appearing in the file
** LICENSE.QPL included in the packaging of this file.
**
** This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
** WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
**
*)
{$I COMPILER.INC}
(*
**
** CRC32 and CRC16 routines for EleBBS
**
** Copyright (c) 1997 by Maarten Bekers
**
** Created : 19-Sep-1997
** Last update : 19-Sep-1997
**
*)

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)
 INTERFACE
(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

uses CfgRec, Cases, ObjDec;

Function  UpdC32(OcTet: Byte; CRC: Longint): Longint;     { CRC32 byte-update }
Function  CRC32(VAR Buf; BufLen:WORD; OldCRC:LONGINT):LONGINT; { calc. CRC32 }
Function  UpdCrc(CP: Byte; CRC: SmallWord): SmallWord;    { CRC16 byte-update }
Function  RAcrc(S:String; ForceUpper: Boolean):LongInt;   { Calculate RA's CRC 32 over a string }
Function  GenFileCRC32(FileName: String): Longint;        { Generate CRC32 from specified file }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)
 IMPLEMENTATION
(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

uses
{$IFDEF WITH_DEBUG}
Debug_U, Global,
{$ENDIF}
FileObj; 

{$R-,S-}

(* Converted to Turbo Pascal (tm) V4.0 March, 1988 by J.R.Louvau       *)
(* Copyright (C) 1986 Gary S. Brown.  You may use this program, or     *)
(* code or tables extracted from it, as desired without restriction.   *)
(*                                                                     *)
(* First, the polynomial itself and its table of feedback terms.  The  *)
(* polynomial is                                                       *)
(* X^32+X^26+X^23+X^22+X^16+X^12+X^11+X^10+X^8+X^7+X^5+X^4+X^2+X^1+X^0 *)
(* Note that we take it "backwards" and put the highest-order term in  *)
(* the lowest-order bit.  The X^32 term is "implied"; the LSB is the   *)
(* X^31 term, etc.  The X^0 term (usually shown as "+1") results in    *)
(* the MSB being 1.                                                    *)
(*                                                                     *)
(* Note that the usual hardware shift register implementation, which   *)
(* is what we're using (we're merely optimizing it by doing eight-bit  *)
(* chunks at a time) shifts bits into the lowest-order term.  In our   *)
(* implementation, that means shifting towards the right.  Why do we   *)
(* do it this way?  Because the calculated CRC must be transmitted in  *)
(* order from highest-order term to lowest-order term.  UARTs transmit *)
(* characters in order from LSB to MSB.  By storing the CRC this way,  *)
(* we hand it to the UART in the order low-byte to high-byte; the UART *)
(* sends each low-bit to hight-bit; and the result is transmission bit *)
(* by bit from highest- to lowest-order term without requiring any bit *)
(* shuffling on our part.  Reception works similarly.                  *)
(*                                                                     *)
(* The feedback terms table consists of 256, 32-bit entries.  Notes:   *)
(*                                                                     *)
(*     The table can be generated at runtime if desired; code to do so *)
(*     is shown later.  It might not be obvious, but the feedback      *)
(*     terms simply represent the results of eight shift/xor opera-    *)
(*     tions for all combinations of data and CRC register values.     *)
(*                                                                     *)
(*     The values must be right-shifted by eight bits by the "updcrc"  *)
(*     logic; the shift must be unsigned (bring in zeroes).  On some   *)
(*     hardware you could probably optimize the shift in assembler by  *)
(*     using byte-swap instructions.                                   *)
(*     polynomial $edb88320                                            *)
(*                                                                     *)

CONST crc_32_tab: ARRAY[0..255] OF LONGINT = (
$00000000, $77073096, $ee0e612c, $990951ba, $076dc419, $706af48f, $e963a535, $9e6495a3,
$0edb8832, $79dcb8a4, $e0d5e91e, $97d2d988, $09b64c2b, $7eb17cbd, $e7b82d07, $90bf1d91,
$1db71064, $6ab020f2, $f3b97148, $84be41de, $1adad47d, $6ddde4eb, $f4d4b551, $83d385c7,
$136c9856, $646ba8c0, $fd62f97a, $8a65c9ec, $14015c4f, $63066cd9, $fa0f3d63, $8d080df5,
$3b6e20c8, $4c69105e, $d56041e4, $a2677172, $3c03e4d1, $4b04d447, $d20d85fd, $a50ab56b,
$35b5a8fa, $42b2986c, $dbbbc9d6, $acbcf940, $32d86ce3, $45df5c75, $dcd60dcf, $abd13d59,
$26d930ac, $51de003a, $c8d75180, $bfd06116, $21b4f4b5, $56b3c423, $cfba9599, $b8bda50f,
$2802b89e, $5f058808, $c60cd9b2, $b10be924, $2f6f7c87, $58684c11, $c1611dab, $b6662d3d,
$76dc4190, $01db7106, $98d220bc, $efd5102a, $71b18589, $06b6b51f, $9fbfe4a5, $e8b8d433,
$7807c9a2, $0f00f934, $9609a88e, $e10e9818, $7f6a0dbb, $086d3d2d, $91646c97, $e6635c01,
$6b6b51f4, $1c6c6162, $856530d8, $f262004e, $6c0695ed, $1b01a57b, $8208f4c1, $f50fc457,
$65b0d9c6, $12b7e950, $8bbeb8ea, $fcb9887c, $62dd1ddf, $15da2d49, $8cd37cf3, $fbd44c65,
$4db26158, $3ab551ce, $a3bc0074, $d4bb30e2, $4adfa541, $3dd895d7, $a4d1c46d, $d3d6f4fb,
$4369e96a, $346ed9fc, $ad678846, $da60b8d0, $44042d73, $33031de5, $aa0a4c5f, $dd0d7cc9,
$5005713c, $270241aa, $be0b1010, $c90c2086, $5768b525, $206f85b3, $b966d409, $ce61e49f,
$5edef90e, $29d9c998, $b0d09822, $c7d7a8b4, $59b33d17, $2eb40d81, $b7bd5c3b, $c0ba6cad,
$edb88320, $9abfb3b6, $03b6e20c, $74b1d29a, $ead54739, $9dd277af, $04db2615, $73dc1683,
$e3630b12, $94643b84, $0d6d6a3e, $7a6a5aa8, $e40ecf0b, $9309ff9d, $0a00ae27, $7d079eb1,
$f00f9344, $8708a3d2, $1e01f268, $6906c2fe, $f762575d, $806567cb, $196c3671, $6e6b06e7,
$fed41b76, $89d32be0, $10da7a5a, $67dd4acc, $f9b9df6f, $8ebeeff9, $17b7be43, $60b08ed5,
$d6d6a3e8, $a1d1937e, $38d8c2c4, $4fdff252, $d1bb67f1, $a6bc5767, $3fb506dd, $48b2364b,
$d80d2bda, $af0a1b4c, $36034af6, $41047a60, $df60efc3, $a867df55, $316e8eef, $4669be79,
$cb61b38c, $bc66831a, $256fd2a0, $5268e236, $cc0c7795, $bb0b4703, $220216b9, $5505262f,
$c5ba3bbe, $b2bd0b28, $2bb45a92, $5cb36a04, $c2d7ffa7, $b5d0cf31, $2cd99e8b, $5bdeae1d,
$9b64c2b0, $ec63f226, $756aa39c, $026d930a, $9c0906a9, $eb0e363f, $72076785, $05005713,
$95bf4a82, $e2b87a14, $7bb12bae, $0cb61b38, $92d28e9b, $e5d5be0d, $7cdcefb7, $0bdbdf21,
$86d3d2d4, $f1d4e242, $68ddb3f8, $1fda836e, $81be16cd, $f6b9265b, $6fb077e1, $18b74777,
$88085ae6, $ff0f6a70, $66063bca, $11010b5c, $8f659eff, $f862ae69, $616bffd3, $166ccf45,
$a00ae278, $d70dd2ee, $4e048354, $3903b3c2, $a7672661, $d06016f7, $4969474d, $3e6e77db,
$aed16a4a, $d9d65adc, $40df0b66, $37d83bf0, $a9bcae53, $debb9ec5, $47b2cf7f, $30b5ffe9,
$bdbdf21c, $cabac28a, $53b39330, $24b4a3a6, $bad03605, $cdd70693, $54de5729, $23d967bf,
$b3667a2e, $c4614ab8, $5d681b02, $2a6f2b94, $b40bbe37, $c30c8ea1, $5a05df1b, $2d02ef8d
);

FUNCTION UpdC32(octet: BYTE; crc: LONGINT) : LONGINT;
BEGIN { UpdC32 }
   UpdC32 := crc_32_tab[BYTE(crc XOR LONGINT(octet))] XOR ((crc SHR 8) AND $00FFFFFF);
END;

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*-*)

(* crctab calculated by Mark G. Mendel, Network Systems Corporation *)
CONST crctab: ARRAY[0..255] OF WORD = (
    $0000,  $1021,  $2042,  $3063,  $4084,  $50a5,  $60c6,  $70e7,
    $8108,  $9129,  $a14a,  $b16b,  $c18c,  $d1ad,  $e1ce,  $f1ef,
    $1231,  $0210,  $3273,  $2252,  $52b5,  $4294,  $72f7,  $62d6,
    $9339,  $8318,  $b37b,  $a35a,  $d3bd,  $c39c,  $f3ff,  $e3de,
    $2462,  $3443,  $0420,  $1401,  $64e6,  $74c7,  $44a4,  $5485,
    $a56a,  $b54b,  $8528,  $9509,  $e5ee,  $f5cf,  $c5ac,  $d58d,
    $3653,  $2672,  $1611,  $0630,  $76d7,  $66f6,  $5695,  $46b4,
    $b75b,  $a77a,  $9719,  $8738,  $f7df,  $e7fe,  $d79d,  $c7bc,
    $48c4,  $58e5,  $6886,  $78a7,  $0840,  $1861,  $2802,  $3823,
    $c9cc,  $d9ed,  $e98e,  $f9af,  $8948,  $9969,  $a90a,  $b92b,
    $5af5,  $4ad4,  $7ab7,  $6a96,  $1a71,  $0a50,  $3a33,  $2a12,
    $dbfd,  $cbdc,  $fbbf,  $eb9e,  $9b79,  $8b58,  $bb3b,  $ab1a,
    $6ca6,  $7c87,  $4ce4,  $5cc5,  $2c22,  $3c03,  $0c60,  $1c41,
    $edae,  $fd8f,  $cdec,  $ddcd,  $ad2a,  $bd0b,  $8d68,  $9d49,
    $7e97,  $6eb6,  $5ed5,  $4ef4,  $3e13,  $2e32,  $1e51,  $0e70,
    $ff9f,  $efbe,  $dfdd,  $cffc,  $bf1b,  $af3a,  $9f59,  $8f78,
    $9188,  $81a9,  $b1ca,  $a1eb,  $d10c,  $c12d,  $f14e,  $e16f,
    $1080,  $00a1,  $30c2,  $20e3,  $5004,  $4025,  $7046,  $6067,
    $83b9,  $9398,  $a3fb,  $b3da,  $c33d,  $d31c,  $e37f,  $f35e,
    $02b1,  $1290,  $22f3,  $32d2,  $4235,  $5214,  $6277,  $7256,
    $b5ea,  $a5cb,  $95a8,  $8589,  $f56e,  $e54f,  $d52c,  $c50d,
    $34e2,  $24c3,  $14a0,  $0481,  $7466,  $6447,  $5424,  $4405,
    $a7db,  $b7fa,  $8799,  $97b8,  $e75f,  $f77e,  $c71d,  $d73c,
    $26d3,  $36f2,  $0691,  $16b0,  $6657,  $7676,  $4615,  $5634,
    $d94c,  $c96d,  $f90e,  $e92f,  $99c8,  $89e9,  $b98a,  $a9ab,
    $5844,  $4865,  $7806,  $6827,  $18c0,  $08e1,  $3882,  $28a3,
    $cb7d,  $db5c,  $eb3f,  $fb1e,  $8bf9,  $9bd8,  $abbb,  $bb9a,
    $4a75,  $5a54,  $6a37,  $7a16,  $0af1,  $1ad0,  $2ab3,  $3a92,
    $fd2e,  $ed0f,  $dd6c,  $cd4d,  $bdaa,  $ad8b,  $9de8,  $8dc9,
    $7c26,  $6c07,  $5c64,  $4c45,  $3ca2,  $2c83,  $1ce0,  $0cc1,
    $ef1f,  $ff3e,  $cf5d,  $df7c,  $af9b,  $bfba,  $8fd9,  $9ff8,
    $6e17,  $7e36,  $4e55,  $5e74,  $2e93,  $3eb2,  $0ed1,  $1ef0
);

(*
 * updcrc derived from article Copyright (C) 1986 Stephen Satchell.
 *  NOTE: First argument must be in range 0 to 255.
 *        Second argument is referenced twice.
 *
 * Programmers may incorporate any or all code into their programs,
 * giving proper credit within the source. Publication of the
 * source routines is permitted so long as proper credit is given
 * to Stephen Satchell, Satchell Evaluations and Chuck Forsberg,
 * Omen Technology.
 *)
FUNCTION UpdCrc(cp: Byte; crc: Smallword): SmallWord;
BEGIN { UpdCrc }
   UpdCrc:= crctab[((crc SHR 8) AND 255)] XOR (crc SHL 8) XOR cp;
END;

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

Function  RAcrc(S:String; ForceUpper: Boolean):LongInt;     { Calculate RA's CRC 32 over a string }
var Counter: Byte;
begin
  {$IFDEF WITH_DEBUG}
    DebugObj.DebugLog(logCrc, 'Calculating CRC32 over (start RaCrc): '+S);
  {$ENDIF}

 if ForceUpper then
   begin
     For Counter := 01 to Length(s) do
       S[Counter] := Cases.UpCase(S[Counter]);
   end; { if }

 RaCRC := Crc32(S[1], Length(S), -1);

  {$ifdef With_Debug} DebugObj.DebugLog(logCrc, 'End of RaCrc: '+S);{$endif}
end; { func. Racrc }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

Function  CRC32(VAR Buf; BufLen:WORD; OldCRC:LONGINT):LONGINT; { calc. CRC32 }
var Counter: Word;
    Buffer: Array[0..60000] of Byte ABSOLUTE Buf;
begin
  {$ifdef With_Debug} DebugObj.DebugLog(logCrc, 'Crc32(Buffer) [Start]');{$endif}

 If BufLen>00 then
  For Counter:=00 to (BufLen-01) do
    OldCrc := UpdC32(Buffer[Counter], OldCrc);

 Crc32 := OldCrc;
  {$ifdef With_Debug} DebugObj.DebugLog(logCrc, 'Crc32(Buffer) [End]');{$endif}
end; { func. Crc32 }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

function GenFileCRC32(FileName: String): Longint;
{
	Generate CRC32 from specified file
}
type
	TSrcBuf = Array[0..4095] of Char;
	PSrcBuf = ^TSrcBuf;

var
	SrcBuf  : PSrcBuf;
	SrcFile : pFileObj;
	SrcRead : Word;
	SrcCRC  : Longint;
begin
	SrcCRC := -1;
	New(SrcBuf);
	New(SrcFile, Init);
	SrcFile^.Assign(FileName);
	SrcFile^.FileMode := ReadMode + DenyNone;

	if SrcFile^.Open(1) then
		begin
			while (not SrcFile^.EOF) do
				begin
					SrcRead := SrcFile^.BlkRead(SrcBuf^, SizeOf(TSrcBuf));
					SrcCRC := CRC32(SrcBuf^, SrcRead, SrcCRC);
				end; { while }
		end; { if }

	Dispose(SrcFile, Done);
	Dispose(SrcBuf);
	GenFileCRC32 := SrcCRC;
end; { func. GenFileCRC32 }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

end.
