<*+O2EXTENSIONS*>
MODULE AggGSVText;

IMPORT
  bas := AggBasics,
  avs := AggVertexSource,
  str := Strings,
  bit := AggBit,

  SYSTEM,
  COMPILER;

TYPE
  Font* = POINTER TO ARRAY MAX(bas.int32) OF bas.int8u;
  Text* = POINTER TO ARRAY OF bas.char;

  PGSV_DEFAULT_FONT* = POINTER TO GSV_DEFAULT_FONT;
  GSV_DEFAULT_FONT*  = ARRAY 4526 OF bas.int8u;

VAR
  gsv_default_font-: PGSV_DEFAULT_FONT;


CONST
  initial*     = 0;
  next_char*   = 1;
  start_glyph* = 2;
  glyph*       = 3;

TYPE
  gsv_text_ptr* = POINTER TO gsv_text;
  gsv_text* = RECORD(avs.vertex_source)
    x           ,
    y           ,
    start_x     ,
    width       ,
    height      ,
    space*      ,
    line_space* : bas.double;
    chr         : ARRAY 2 OF bas.char;
    text        ,
    text_buf    : Text;
    buf_size    : bas.int32;
    cur_chr     : bas.int32;
    font        ,
    loaded_font : Font;
    loadfont_sz : bas.int32;
    status      : bas.int32;
    big_endian  ,
    flip*       : BOOLEAN;

    indices : bas.int32;
    glyphs  ,
    bglyph  ,
    eglyph  : bas.int32;
    w       ,
    h       : bas.double;
  END;

PROCEDURE (gsv: gsv_text_ptr) Construct*();
BEGIN
  gsv.Construct^();

  gsv.x          := 0.0;
  gsv.y          := 0.0;
  gsv.start_x    := 0.0;
  gsv.width      :=10.0;
  gsv.height     := 0.0;
  gsv.space      := 0.0;
  gsv.line_space := 0.0;
  gsv.text       := NIL;
  gsv.text_buf   := NIL;
  gsv.buf_size   := 0;
  gsv.cur_chr    := 0;
  gsv.font       := SYSTEM.VAL(Font, gsv_default_font);
  gsv.loaded_font:= NIL;
  gsv.loadfont_sz:= 0;
  gsv.status     := initial;
  gsv.flip       := FALSE;

  gsv.chr[0] := 0X;
  gsv.chr[1] := 0X;


  gsv.big_endian := COMPILER.OPTION("TARGET_BIGENDIAN");

END Construct;

PROCEDURE (gsv: gsv_text_ptr) Destruct*();
BEGIN
  gsv.loaded_font := NIL;
  gsv.text_buf := NIL;

  gsv.Destruct^();
END Destruct;

PROCEDURE (gsv: gsv_text_ptr) set_font*(font: Font);
BEGIN
  IF font # NIL THEN
    gsv.font := font;
  ELSE
    gsv.font := SYSTEM.VAL(Font, gsv_default_font);
  END;
END set_font;

PROCEDURE (gsv: gsv_text_ptr) set_size*(height: bas.double; width: bas.double);
BEGIN
  gsv.height := height;
  gsv.width  := width;
END set_size;

PROCEDURE (gsv: gsv_text_ptr) set_start_point*(x, y: bas.double);
BEGIN
  gsv.x := x;
  gsv.y := y;
  gsv.start_x := x;
END set_start_point;

PROCEDURE (gsv: gsv_text_ptr) set_text*(text: ARRAY OF bas.char);
VAR
  new_size: bas.int32;
BEGIN
  IF str.Length(text) = 0 THEN
    gsv.text := NIL;
    RETURN;
  END;

  new_size := str.Length(text) + 1;

  IF new_size > gsv.buf_size THEN
    NEW(gsv.text_buf, new_size);
    gsv.buf_size := new_size;
  END;

  COPY(text, gsv.text_buf^);
  gsv.text := gsv.text_buf;
END set_text;

<*+WOFF301*>
PROCEDURE (gsv: gsv_text_ptr) rewind*(path_id: bas.int32u);
VAR
  base_height: bas.double;
BEGIN
  gsv.status := initial;

  IF gsv.font = NIL THEN
    RETURN;
  END;

  gsv.indices := 0;

  base_height := gsv.font[4] + 256 * gsv.font[5];

  gsv.indices := gsv.font[0] + 256 * gsv.font[1];

  INC(gsv.indices, gsv.font[gsv.indices] + 256 * gsv.font[gsv.indices + 1]);

  gsv.glyphs  := gsv.indices + 257 * 2;

  gsv.h := gsv.height / base_height;

  IF gsv.width = 0 THEN
    gsv.w := gsv.h
  ELSE
    gsv.w := gsv.width / base_height;
  END;

  IF gsv.flip THEN
    gsv.h := -gsv.h;
  END;

  gsv.cur_chr := 0;
END rewind;
<*-WOFF301*>

PROCEDURE (gsv: gsv_text_ptr) vertex*(VAR x, y: bas.double): SET;
VAR
  idx: bas.int32;

  yc, yf: bas.int8;
  dx, dy: bas.int8;
  quit: BOOLEAN;
BEGIN
  quit := FALSE;

  LOOP
    IF quit THEN EXIT END;

    IF gsv.status = initial THEN
      IF gsv.font = NIL THEN
        quit := TRUE;
      ELSE
        gsv.status := next_char;
      END;
    ELSIF gsv.status = next_char THEN
      IF gsv.text[gsv.cur_chr] = 0X THEN
        quit := TRUE;
      ELSE
        idx := ORD(gsv.text[gsv.cur_chr]);
        INC(gsv.cur_chr);

        IF idx = 13 THEN
          gsv.x := gsv.start_x;

          IF gsv.flip THEN
            gsv.y := gsv.y - (-gsv.height - gsv.line_space)
          ELSE
            gsv.y := gsv.y - ( gsv.height + gsv.line_space);
          END;
        ELSE
          idx := ASH(idx, 1);
          gsv.bglyph := gsv.glyphs + gsv.font[gsv.indices + idx]     + 256 * gsv.font[gsv.indices + idx + 1];
          gsv.eglyph := gsv.glyphs + gsv.font[gsv.indices + idx + 2] + 256 * gsv.font[gsv.indices + idx + 2 + 1];
          gsv.status := start_glyph;
        END;
      END;
    ELSIF gsv.status = start_glyph THEN
      x := gsv.x;
      y := gsv.y;
      gsv.status := glyph;
      RETURN bas.path_cmd_move_to;
    ELSIF gsv.status = glyph THEN
      IF gsv.bglyph >= gsv.eglyph THEN
        gsv.status := next_char;
        x := gsv.x + gsv.space;
      ELSE
        dx := SYSTEM.VAL(bas.int8, gsv.font[gsv.bglyph]);

        INC(gsv.bglyph);

        yc := SYSTEM.VAL(bas.int8, gsv.font[gsv.bglyph]);

        INC(gsv.bglyph);

        yf := bit.and8(yc, 80H);
        yc := SYSTEM.VAL(bas.int8, ASH(yc, 1));
        yc := SYSTEM.VAL(bas.int8, bas.shr_int32(yc, 1));

        dy := yc;

        gsv.x := gsv.x + (dx * gsv.w);
        gsv.y := gsv.y + (dy * gsv.h);

        x := gsv.x;
        y := gsv.y;

        IF yf # 0 THEN
          RETURN bas.path_cmd_move_to
        ELSE
          RETURN bas.path_cmd_line_to;
        END;
      END;
    END;
  END;
  RETURN bas.path_cmd_stop;
END vertex;

BEGIN
  NEW(gsv_default_font);
  gsv_default_font^ := GSV_DEFAULT_FONT{
  040H,000H,06cH,00fH,015H,000H,00eH,000H,0f9H,0ffH,
  000H,000H,000H,000H,000H,000H,000H,000H,000H,000H,
  00dH,00aH,00dH,00aH,046H,06fH,06eH,074H,020H,028H,
  063H,029H,020H,04dH,069H,063H,072H,06fH,050H,072H,
  06fH,066H,020H,032H,037H,020H,053H,065H,070H,074H,
  065H,06dH,062H,02eH,031H,039H,038H,039H,000H,00dH,
  00aH,00dH,00aH,000H,000H,000H,000H,000H,000H,000H,
  000H,000H,000H,000H,000H,000H,000H,000H,000H,000H,
  000H,000H,000H,000H,000H,000H,000H,000H,000H,000H,
  000H,000H,000H,000H,000H,000H,000H,000H,000H,000H,
  000H,000H,000H,000H,000H,000H,000H,000H,000H,000H,
  000H,000H,000H,000H,000H,000H,000H,000H,000H,000H,
  000H,000H,000H,000H,000H,000H,000H,000H,000H,000H,
  002H,000H,012H,000H,034H,000H,046H,000H,094H,000H,
  0d0H,000H,02eH,001H,03eH,001H,064H,001H,08aH,001H,
  098H,001H,0a2H,001H,0b4H,001H,0baH,001H,0c6H,001H,
  0ccH,001H,0f0H,001H,0faH,001H,018H,002H,038H,002H,
  044H,002H,068H,002H,098H,002H,0a2H,002H,0deH,002H,
  00eH,003H,024H,003H,040H,003H,048H,003H,052H,003H,
  05aH,003H,082H,003H,0ecH,003H,0faH,003H,026H,004H,
  04cH,004H,06aH,004H,07cH,004H,08aH,004H,0b6H,004H,
  0c4H,004H,0caH,004H,0e0H,004H,0eeH,004H,0f8H,004H,
  00aH,005H,018H,005H,044H,005H,05eH,005H,08eH,005H,
  0acH,005H,0d6H,005H,0e0H,005H,0f6H,005H,000H,006H,
  012H,006H,01cH,006H,028H,006H,036H,006H,048H,006H,
  04eH,006H,060H,006H,06eH,006H,074H,006H,084H,006H,
  0a6H,006H,0c8H,006H,0e6H,006H,008H,007H,02cH,007H,
  03cH,007H,068H,007H,07cH,007H,08cH,007H,0a2H,007H,
  0b0H,007H,0b6H,007H,0d8H,007H,0ecH,007H,010H,008H,
  032H,008H,054H,008H,064H,008H,088H,008H,098H,008H,
  0acH,008H,0b6H,008H,0c8H,008H,0d2H,008H,0e4H,008H,
  0f2H,008H,03eH,009H,048H,009H,094H,009H,0c2H,009H,
  0c4H,009H,0d0H,009H,0e2H,009H,004H,00aH,00eH,00aH,
  026H,00aH,034H,00aH,04aH,00aH,066H,00aH,070H,00aH,
  07eH,00aH,08eH,00aH,09aH,00aH,0a6H,00aH,0b4H,00aH,
  0d8H,00aH,0e2H,00aH,0f6H,00aH,018H,00bH,022H,00bH,
  032H,00bH,056H,00bH,060H,00bH,06eH,00bH,07cH,00bH,
  08aH,00bH,09cH,00bH,09eH,00bH,0b2H,00bH,0c2H,00bH,
  0d8H,00bH,0f4H,00bH,008H,00cH,030H,00cH,056H,00cH,
  072H,00cH,090H,00cH,0b2H,00cH,0ceH,00cH,0e2H,00cH,
  0feH,00cH,010H,00dH,026H,00dH,036H,00dH,042H,00dH,
  04eH,00dH,05cH,00dH,078H,00dH,08cH,00dH,08eH,00dH,
  090H,00dH,092H,00dH,094H,00dH,096H,00dH,098H,00dH,
  09aH,00dH,09cH,00dH,09eH,00dH,0a0H,00dH,0a2H,00dH,
  0a4H,00dH,0a6H,00dH,0a8H,00dH,0aaH,00dH,0acH,00dH,
  0aeH,00dH,0b0H,00dH,0b2H,00dH,0b4H,00dH,0b6H,00dH,
  0b8H,00dH,0baH,00dH,0bcH,00dH,0beH,00dH,0c0H,00dH,
  0c2H,00dH,0c4H,00dH,0c6H,00dH,0c8H,00dH,0caH,00dH,
  0ccH,00dH,0ceH,00dH,0d0H,00dH,0d2H,00dH,0d4H,00dH,
  0d6H,00dH,0d8H,00dH,0daH,00dH,0dcH,00dH,0deH,00dH,
  0e0H,00dH,0e2H,00dH,0e4H,00dH,0e6H,00dH,0e8H,00dH,
  0eaH,00dH,0ecH,00dH,00cH,00eH,026H,00eH,048H,00eH,
  064H,00eH,088H,00eH,092H,00eH,0a6H,00eH,0b4H,00eH,
  0d0H,00eH,0eeH,00eH,002H,00fH,016H,00fH,026H,00fH,
  03cH,00fH,058H,00fH,06cH,00fH,06cH,00fH,06cH,00fH,
  06cH,00fH,06cH,00fH,06cH,00fH,06cH,00fH,06cH,00fH,
  06cH,00fH,06cH,00fH,06cH,00fH,06cH,00fH,06cH,00fH,
  06cH,00fH,06cH,00fH,06cH,00fH,06cH,00fH,010H,080H,
  005H,095H,000H,072H,000H,0fbH,0ffH,07fH,001H,07fH,
  001H,001H,0ffH,001H,005H,0feH,005H,095H,0ffH,07fH,
  000H,07aH,001H,086H,0ffH,07aH,001H,087H,001H,07fH,
  0feH,07aH,00aH,087H,0ffH,07fH,000H,07aH,001H,086H,
  0ffH,07aH,001H,087H,001H,07fH,0feH,07aH,005H,0f2H,
  00bH,095H,0f9H,064H,00dH,09cH,0f9H,064H,0faH,091H,
  00eH,000H,0f1H,0faH,00eH,000H,004H,0fcH,008H,099H,
  000H,063H,004H,09dH,000H,063H,004H,096H,0ffH,07fH,
  001H,07fH,001H,001H,000H,001H,0feH,002H,0fdH,001H,
  0fcH,000H,0fdH,07fH,0feH,07eH,000H,07eH,001H,07eH,
  001H,07fH,002H,07fH,006H,07eH,002H,07fH,002H,07eH,
  0f2H,089H,002H,07eH,002H,07fH,006H,07eH,002H,07fH,
  001H,07fH,001H,07eH,000H,07cH,0feH,07eH,0fdH,07fH,
  0fcH,000H,0fdH,001H,0feH,002H,000H,001H,001H,001H,
  001H,07fH,0ffH,07fH,010H,0fdH,015H,095H,0eeH,06bH,
  005H,095H,002H,07eH,000H,07eH,0ffH,07eH,0feH,07fH,
  0feH,000H,0feH,002H,000H,002H,001H,002H,002H,001H,
  002H,000H,002H,07fH,003H,07fH,003H,000H,003H,001H,
  002H,001H,0fcH,0f2H,0feH,07fH,0ffH,07eH,000H,07eH,
  002H,07eH,002H,000H,002H,001H,001H,002H,000H,002H,
  0feH,002H,0feH,000H,007H,0f9H,015H,08dH,0ffH,07fH,
  001H,07fH,001H,001H,000H,001H,0ffH,001H,0ffH,000H,
  0ffH,07fH,0ffH,07eH,0feH,07bH,0feH,07dH,0feH,07eH,
  0feH,07fH,0fdH,000H,0fdH,001H,0ffH,002H,000H,003H,
  001H,002H,006H,004H,002H,002H,001H,002H,000H,002H,
  0ffH,002H,0feH,001H,0feH,07fH,0ffH,07eH,000H,07eH,
  001H,07dH,002H,07dH,005H,079H,002H,07eH,003H,07fH,
  001H,000H,001H,001H,000H,001H,0f1H,0feH,0feH,001H,
  0ffH,002H,000H,003H,001H,002H,002H,002H,000H,086H,
  001H,07eH,008H,075H,002H,07eH,002H,07fH,005H,080H,
  005H,093H,0ffH,001H,001H,001H,001H,07fH,000H,07eH,
  0ffH,07eH,0ffH,07fH,006H,0f1H,00bH,099H,0feH,07eH,
  0feH,07dH,0feH,07cH,0ffH,07bH,000H,07cH,001H,07bH,
  002H,07cH,002H,07dH,002H,07eH,0feH,09eH,0feH,07cH,
  0ffH,07dH,0ffH,07bH,000H,07cH,001H,07bH,001H,07dH,
  002H,07cH,005H,085H,003H,099H,002H,07eH,002H,07dH,
  002H,07cH,001H,07bH,000H,07cH,0ffH,07bH,0feH,07cH,
  0feH,07dH,0feH,07eH,002H,09eH,002H,07cH,001H,07dH,
  001H,07bH,000H,07cH,0ffH,07bH,0ffH,07dH,0feH,07cH,
  009H,085H,008H,095H,000H,074H,0fbH,089H,00aH,07aH,
  000H,086H,0f6H,07aH,00dH,0f4H,00dH,092H,000H,06eH,
  0f7H,089H,012H,000H,004H,0f7H,006H,081H,0ffH,07fH,
  0ffH,001H,001H,001H,001H,07fH,000H,07eH,0ffH,07eH,
  0ffH,07fH,006H,084H,004H,089H,012H,000H,004H,0f7H,
  005H,082H,0ffH,07fH,001H,07fH,001H,001H,0ffH,001H,
  005H,0feH,000H,0fdH,00eH,018H,000H,0ebH,009H,095H,
  0fdH,07fH,0feH,07dH,0ffH,07bH,000H,07dH,001H,07bH,
  002H,07dH,003H,07fH,002H,000H,003H,001H,002H,003H,
  001H,005H,000H,003H,0ffH,005H,0feH,003H,0fdH,001H,
  0feH,000H,00bH,0ebH,006H,091H,002H,001H,003H,003H,
  000H,06bH,009H,080H,004H,090H,000H,001H,001H,002H,
  001H,001H,002H,001H,004H,000H,002H,07fH,001H,07fH,
  001H,07eH,000H,07eH,0ffH,07eH,0feH,07dH,0f6H,076H,
  00eH,000H,003H,080H,005H,095H,00bH,000H,0faH,078H,
  003H,000H,002H,07fH,001H,07fH,001H,07dH,000H,07eH,
  0ffH,07dH,0feH,07eH,0fdH,07fH,0fdH,000H,0fdH,001H,
  0ffH,001H,0ffH,002H,011H,0fcH,00dH,095H,0f6H,072H,
  00fH,000H,0fbH,08eH,000H,06bH,007H,080H,00fH,095H,
  0f6H,000H,0ffH,077H,001H,001H,003H,001H,003H,000H,
  003H,07fH,002H,07eH,001H,07dH,000H,07eH,0ffH,07dH,
  0feH,07eH,0fdH,07fH,0fdH,000H,0fdH,001H,0ffH,001H,
  0ffH,002H,011H,0fcH,010H,092H,0ffH,002H,0fdH,001H,
  0feH,000H,0fdH,07fH,0feH,07dH,0ffH,07bH,000H,07bH,
  001H,07cH,002H,07eH,003H,07fH,001H,000H,003H,001H,
  002H,002H,001H,003H,000H,001H,0ffH,003H,0feH,002H,
  0fdH,001H,0ffH,000H,0fdH,07fH,0feH,07eH,0ffH,07dH,
  010H,0f9H,011H,095H,0f6H,06bH,0fcH,095H,00eH,000H,
  003H,0ebH,008H,095H,0fdH,07fH,0ffH,07eH,000H,07eH,
  001H,07eH,002H,07fH,004H,07fH,003H,07fH,002H,07eH,
  001H,07eH,000H,07dH,0ffH,07eH,0ffH,07fH,0fdH,07fH,
  0fcH,000H,0fdH,001H,0ffH,001H,0ffH,002H,000H,003H,
  001H,002H,002H,002H,003H,001H,004H,001H,002H,001H,
  001H,002H,000H,002H,0ffH,002H,0fdH,001H,0fcH,000H,
  00cH,0ebH,010H,08eH,0ffH,07dH,0feH,07eH,0fdH,07fH,
  0ffH,000H,0fdH,001H,0feH,002H,0ffH,003H,000H,001H,
  001H,003H,002H,002H,003H,001H,001H,000H,003H,07fH,
  002H,07eH,001H,07cH,000H,07bH,0ffH,07bH,0feH,07dH,
  0fdH,07fH,0feH,000H,0fdH,001H,0ffH,002H,010H,0fdH,
  005H,08eH,0ffH,07fH,001H,07fH,001H,001H,0ffH,001H,
  000H,0f4H,0ffH,07fH,001H,07fH,001H,001H,0ffH,001H,
  005H,0feH,005H,08eH,0ffH,07fH,001H,07fH,001H,001H,
  0ffH,001H,001H,0f3H,0ffH,07fH,0ffH,001H,001H,001H,
  001H,07fH,000H,07eH,0ffH,07eH,0ffH,07fH,006H,084H,
  014H,092H,0f0H,077H,010H,077H,004H,080H,004H,08cH,
  012H,000H,0eeH,0faH,012H,000H,004H,0faH,004H,092H,
  010H,077H,0f0H,077H,014H,080H,003H,090H,000H,001H,
  001H,002H,001H,001H,002H,001H,004H,000H,002H,07fH,
  001H,07fH,001H,07eH,000H,07eH,0ffH,07eH,0ffH,07fH,
  0fcH,07eH,000H,07dH,000H,0fbH,0ffH,07fH,001H,07fH,
  001H,001H,0ffH,001H,009H,0feH,012H,08dH,0ffH,002H,
  0feH,001H,0fdH,000H,0feH,07fH,0ffH,07fH,0ffH,07dH,
  000H,07dH,001H,07eH,002H,07fH,003H,000H,002H,001H,
  001H,002H,0fbH,088H,0feH,07eH,0ffH,07dH,000H,07dH,
  001H,07eH,001H,07fH,007H,08bH,0ffH,078H,000H,07eH,
  002H,07fH,002H,000H,002H,002H,001H,003H,000H,002H,
  0ffH,003H,0ffH,002H,0feH,002H,0feH,001H,0fdH,001H,
  0fdH,000H,0fdH,07fH,0feH,07fH,0feH,07eH,0ffH,07eH,
  0ffH,07dH,000H,07dH,001H,07dH,001H,07eH,002H,07eH,
  002H,07fH,003H,07fH,003H,000H,003H,001H,002H,001H,
  001H,001H,0feH,08dH,0ffH,078H,000H,07eH,001H,07fH,
  008H,0fbH,009H,095H,0f8H,06bH,008H,095H,008H,06bH,
  0f3H,087H,00aH,000H,004H,0f9H,004H,095H,000H,06bH,
  000H,095H,009H,000H,003H,07fH,001H,07fH,001H,07eH,
  000H,07eH,0ffH,07eH,0ffH,07fH,0fdH,07fH,0f7H,080H,
  009H,000H,003H,07fH,001H,07fH,001H,07eH,000H,07dH,
  0ffH,07eH,0ffH,07fH,0fdH,07fH,0f7H,000H,011H,080H,
  012H,090H,0ffH,002H,0feH,002H,0feH,001H,0fcH,000H,
  0feH,07fH,0feH,07eH,0ffH,07eH,0ffH,07dH,000H,07bH,
  001H,07dH,001H,07eH,002H,07eH,002H,07fH,004H,000H,
  002H,001H,002H,002H,001H,002H,003H,0fbH,004H,095H,
  000H,06bH,000H,095H,007H,000H,003H,07fH,002H,07eH,
  001H,07eH,001H,07dH,000H,07bH,0ffH,07dH,0ffH,07eH,
  0feH,07eH,0fdH,07fH,0f9H,000H,011H,080H,004H,095H,
  000H,06bH,000H,095H,00dH,000H,0f3H,0f6H,008H,000H,
  0f8H,0f5H,00dH,000H,002H,080H,004H,095H,000H,06bH,
  000H,095H,00dH,000H,0f3H,0f6H,008H,000H,006H,0f5H,
  012H,090H,0ffH,002H,0feH,002H,0feH,001H,0fcH,000H,
  0feH,07fH,0feH,07eH,0ffH,07eH,0ffH,07dH,000H,07bH,
  001H,07dH,001H,07eH,002H,07eH,002H,07fH,004H,000H,
  002H,001H,002H,002H,001H,002H,000H,003H,0fbH,080H,
  005H,000H,003H,0f8H,004H,095H,000H,06bH,00eH,095H,
  000H,06bH,0f2H,08bH,00eH,000H,004H,0f5H,004H,095H,
  000H,06bH,004H,080H,00cH,095H,000H,070H,0ffH,07dH,
  0ffH,07fH,0feH,07fH,0feH,000H,0feH,001H,0ffH,001H,
  0ffH,003H,000H,002H,00eH,0f9H,004H,095H,000H,06bH,
  00eH,095H,0f2H,072H,005H,085H,009H,074H,003H,080H,
  004H,095H,000H,06bH,000H,080H,00cH,000H,001H,080H,
  004H,095H,000H,06bH,000H,095H,008H,06bH,008H,095H,
  0f8H,06bH,008H,095H,000H,06bH,004H,080H,004H,095H,
  000H,06bH,000H,095H,00eH,06bH,000H,095H,000H,06bH,
  004H,080H,009H,095H,0feH,07fH,0feH,07eH,0ffH,07eH,
  0ffH,07dH,000H,07bH,001H,07dH,001H,07eH,002H,07eH,
  002H,07fH,004H,000H,002H,001H,002H,002H,001H,002H,
  001H,003H,000H,005H,0ffH,003H,0ffH,002H,0feH,002H,
  0feH,001H,0fcH,000H,00dH,0ebH,004H,095H,000H,06bH,
  000H,095H,009H,000H,003H,07fH,001H,07fH,001H,07eH,
  000H,07dH,0ffH,07eH,0ffH,07fH,0fdH,07fH,0f7H,000H,
  011H,0f6H,009H,095H,0feH,07fH,0feH,07eH,0ffH,07eH,
  0ffH,07dH,000H,07bH,001H,07dH,001H,07eH,002H,07eH,
  002H,07fH,004H,000H,002H,001H,002H,002H,001H,002H,
  001H,003H,000H,005H,0ffH,003H,0ffH,002H,0feH,002H,
  0feH,001H,0fcH,000H,003H,0efH,006H,07aH,004H,082H,
  004H,095H,000H,06bH,000H,095H,009H,000H,003H,07fH,
  001H,07fH,001H,07eH,000H,07eH,0ffH,07eH,0ffH,07fH,
  0fdH,07fH,0f7H,000H,007H,080H,007H,075H,003H,080H,
  011H,092H,0feH,002H,0fdH,001H,0fcH,000H,0fdH,07fH,
  0feH,07eH,000H,07eH,001H,07eH,001H,07fH,002H,07fH,
  006H,07eH,002H,07fH,001H,07fH,001H,07eH,000H,07dH,
  0feH,07eH,0fdH,07fH,0fcH,000H,0fdH,001H,0feH,002H,
  011H,0fdH,008H,095H,000H,06bH,0f9H,095H,00eH,000H,
  001H,0ebH,004H,095H,000H,071H,001H,07dH,002H,07eH,
  003H,07fH,002H,000H,003H,001H,002H,002H,001H,003H,
  000H,00fH,004H,0ebH,001H,095H,008H,06bH,008H,095H,
  0f8H,06bH,009H,080H,002H,095H,005H,06bH,005H,095H,
  0fbH,06bH,005H,095H,005H,06bH,005H,095H,0fbH,06bH,
  007H,080H,003H,095H,00eH,06bH,000H,095H,0f2H,06bH,
  011H,080H,001H,095H,008H,076H,000H,075H,008H,095H,
  0f8H,076H,009H,0f5H,011H,095H,0f2H,06bH,000H,095H,
  00eH,000H,0f2H,0ebH,00eH,000H,003H,080H,003H,093H,
  000H,06cH,001H,094H,000H,06cH,0ffH,094H,005H,000H,
  0fbH,0ecH,005H,000H,002H,081H,000H,095H,00eH,068H,
  000H,083H,006H,093H,000H,06cH,001H,094H,000H,06cH,
  0fbH,094H,005H,000H,0fbH,0ecH,005H,000H,003H,081H,
  003H,087H,008H,005H,008H,07bH,0f0H,080H,008H,004H,
  008H,07cH,003H,0f9H,001H,080H,010H,000H,001H,080H,
  006H,095H,0ffH,07fH,0ffH,07eH,000H,07eH,001H,07fH,
  001H,001H,0ffH,001H,005H,0efH,00fH,08eH,000H,072H,
  000H,08bH,0feH,002H,0feH,001H,0fdH,000H,0feH,07fH,
  0feH,07eH,0ffH,07dH,000H,07eH,001H,07dH,002H,07eH,
  002H,07fH,003H,000H,002H,001H,002H,002H,004H,0fdH,
  004H,095H,000H,06bH,000H,08bH,002H,002H,002H,001H,
  003H,000H,002H,07fH,002H,07eH,001H,07dH,000H,07eH,
  0ffH,07dH,0feH,07eH,0feH,07fH,0fdH,000H,0feH,001H,
  0feH,002H,00fH,0fdH,00fH,08bH,0feH,002H,0feH,001H,
  0fdH,000H,0feH,07fH,0feH,07eH,0ffH,07dH,000H,07eH,
  001H,07dH,002H,07eH,002H,07fH,003H,000H,002H,001H,
  002H,002H,003H,0fdH,00fH,095H,000H,06bH,000H,08bH,
  0feH,002H,0feH,001H,0fdH,000H,0feH,07fH,0feH,07eH,
  0ffH,07dH,000H,07eH,001H,07dH,002H,07eH,002H,07fH,
  003H,000H,002H,001H,002H,002H,004H,0fdH,003H,088H,
  00cH,000H,000H,002H,0ffH,002H,0ffH,001H,0feH,001H,
  0fdH,000H,0feH,07fH,0feH,07eH,0ffH,07dH,000H,07eH,
  001H,07dH,002H,07eH,002H,07fH,003H,000H,002H,001H,
  002H,002H,003H,0fdH,00aH,095H,0feH,000H,0feH,07fH,
  0ffH,07dH,000H,06fH,0fdH,08eH,007H,000H,003H,0f2H,
  00fH,08eH,000H,070H,0ffH,07dH,0ffH,07fH,0feH,07fH,
  0fdH,000H,0feH,001H,009H,091H,0feH,002H,0feH,001H,
  0fdH,000H,0feH,07fH,0feH,07eH,0ffH,07dH,000H,07eH,
  001H,07dH,002H,07eH,002H,07fH,003H,000H,002H,001H,
  002H,002H,004H,0fdH,004H,095H,000H,06bH,000H,08aH,
  003H,003H,002H,001H,003H,000H,002H,07fH,001H,07dH,
  000H,076H,004H,080H,003H,095H,001H,07fH,001H,001H,
  0ffH,001H,0ffH,07fH,001H,0f9H,000H,072H,004H,080H,
  005H,095H,001H,07fH,001H,001H,0ffH,001H,0ffH,07fH,
  001H,0f9H,000H,06fH,0ffH,07dH,0feH,07fH,0feH,000H,
  009H,087H,004H,095H,000H,06bH,00aH,08eH,0f6H,076H,
  004H,084H,007H,078H,002H,080H,004H,095H,000H,06bH,
  004H,080H,004H,08eH,000H,072H,000H,08aH,003H,003H,
  002H,001H,003H,000H,002H,07fH,001H,07dH,000H,076H,
  000H,08aH,003H,003H,002H,001H,003H,000H,002H,07fH,
  001H,07dH,000H,076H,004H,080H,004H,08eH,000H,072H,
  000H,08aH,003H,003H,002H,001H,003H,000H,002H,07fH,
  001H,07dH,000H,076H,004H,080H,008H,08eH,0feH,07fH,
  0feH,07eH,0ffH,07dH,000H,07eH,001H,07dH,002H,07eH,
  002H,07fH,003H,000H,002H,001H,002H,002H,001H,003H,
  000H,002H,0ffH,003H,0feH,002H,0feH,001H,0fdH,000H,
  00bH,0f2H,004H,08eH,000H,06bH,000H,092H,002H,002H,
  002H,001H,003H,000H,002H,07fH,002H,07eH,001H,07dH,
  000H,07eH,0ffH,07dH,0feH,07eH,0feH,07fH,0fdH,000H,
  0feH,001H,0feH,002H,00fH,0fdH,00fH,08eH,000H,06bH,
  000H,092H,0feH,002H,0feH,001H,0fdH,000H,0feH,07fH,
  0feH,07eH,0ffH,07dH,000H,07eH,001H,07dH,002H,07eH,
  002H,07fH,003H,000H,002H,001H,002H,002H,004H,0fdH,
  004H,08eH,000H,072H,000H,088H,001H,003H,002H,002H,
  002H,001H,003H,000H,001H,0f2H,00eH,08bH,0ffH,002H,
  0fdH,001H,0fdH,000H,0fdH,07fH,0ffH,07eH,001H,07eH,
  002H,07fH,005H,07fH,002H,07fH,001H,07eH,000H,07fH,
  0ffH,07eH,0fdH,07fH,0fdH,000H,0fdH,001H,0ffH,002H,
  00eH,0fdH,005H,095H,000H,06fH,001H,07dH,002H,07fH,
  002H,000H,0f8H,08eH,007H,000H,003H,0f2H,004H,08eH,
  000H,076H,001H,07dH,002H,07fH,003H,000H,002H,001H,
  003H,003H,000H,08aH,000H,072H,004H,080H,002H,08eH,
  006H,072H,006H,08eH,0faH,072H,008H,080H,003H,08eH,
  004H,072H,004H,08eH,0fcH,072H,004H,08eH,004H,072H,
  004H,08eH,0fcH,072H,007H,080H,003H,08eH,00bH,072H,
  000H,08eH,0f5H,072H,00eH,080H,002H,08eH,006H,072H,
  006H,08eH,0faH,072H,0feH,07cH,0feH,07eH,0feH,07fH,
  0ffH,000H,00fH,087H,00eH,08eH,0f5H,072H,000H,08eH,
  00bH,000H,0f5H,0f2H,00bH,000H,003H,080H,009H,099H,
  0feH,07fH,0ffH,07fH,0ffH,07eH,000H,07eH,001H,07eH,
  001H,07fH,001H,07eH,000H,07eH,0feH,07eH,001H,08eH,
  0ffH,07eH,000H,07eH,001H,07eH,001H,07fH,001H,07eH,
  000H,07eH,0ffH,07eH,0fcH,07eH,004H,07eH,001H,07eH,
  000H,07eH,0ffH,07eH,0ffH,07fH,0ffH,07eH,000H,07eH,
  001H,07eH,0ffH,08eH,002H,07eH,000H,07eH,0ffH,07eH,
  0ffH,07fH,0ffH,07eH,000H,07eH,001H,07eH,001H,07fH,
  002H,07fH,005H,087H,004H,095H,000H,077H,000H,0fdH,
  000H,077H,004H,080H,005H,099H,002H,07fH,001H,07fH,
  001H,07eH,000H,07eH,0ffH,07eH,0ffH,07fH,0ffH,07eH,
  000H,07eH,002H,07eH,0ffH,08eH,001H,07eH,000H,07eH,
  0ffH,07eH,0ffH,07fH,0ffH,07eH,000H,07eH,001H,07eH,
  004H,07eH,0fcH,07eH,0ffH,07eH,000H,07eH,001H,07eH,
  001H,07fH,001H,07eH,000H,07eH,0ffH,07eH,001H,08eH,
  0feH,07eH,000H,07eH,001H,07eH,001H,07fH,001H,07eH,
  000H,07eH,0ffH,07eH,0ffH,07fH,0feH,07fH,009H,087H,
  003H,086H,000H,002H,001H,003H,002H,001H,002H,000H,
  002H,07fH,004H,07dH,002H,07fH,002H,000H,002H,001H,
  001H,002H,0eeH,0feH,001H,002H,002H,001H,002H,000H,
  002H,07fH,004H,07dH,002H,07fH,002H,000H,002H,001H,
  001H,003H,000H,002H,003H,0f4H,010H,080H,003H,080H,
  007H,015H,008H,06bH,0feH,085H,0f5H,000H,010H,0fbH,
  00dH,095H,0f6H,000H,000H,06bH,00aH,000H,002H,002H,
  000H,008H,0feH,002H,0f6H,000H,00eH,0f4H,003H,080H,
  000H,015H,00aH,000H,002H,07eH,000H,07eH,000H,07dH,
  000H,07eH,0feH,07fH,0f6H,000H,00aH,080H,002H,07eH,
  001H,07eH,000H,07dH,0ffH,07dH,0feH,07fH,0f6H,000H,
  010H,080H,003H,080H,000H,015H,00cH,000H,0ffH,07eH,
  003H,0edH,003H,0fdH,000H,003H,002H,000H,000H,012H,
  002H,003H,00aH,000H,000H,06bH,002H,000H,000H,07dH,
  0feH,083H,0f4H,000H,011H,080H,00fH,080H,0f4H,000H,
  000H,015H,00cH,000H,0ffH,0f6H,0f5H,000H,00fH,0f5H,
  004H,095H,007H,076H,000H,00aH,007H,080H,0f9H,076H,
  000H,075H,0f8H,080H,007H,00cH,009H,0f4H,0f9H,00cH,
  009H,0f4H,003H,092H,002H,003H,007H,000H,003H,07dH,
  000H,07bH,0fcH,07eH,004H,07dH,000H,07aH,0fdH,07eH,
  0f9H,000H,0feH,002H,006H,089H,002H,000H,006H,0f5H,
  003H,095H,000H,06bH,00cH,015H,000H,06bH,002H,080H,
  003H,095H,000H,06bH,00cH,015H,000H,06bH,0f8H,096H,
  003H,000H,007H,0eaH,003H,080H,000H,015H,00cH,080H,
  0f7H,076H,0fdH,000H,003H,080H,00aH,075H,003H,080H,
  003H,080H,007H,013H,002H,002H,003H,000H,000H,06bH,
  002H,080H,003H,080H,000H,015H,009H,06bH,009H,015H,
  000H,06bH,003H,080H,003H,080H,000H,015H,000H,0f6H,
  00dH,000H,000H,08aH,000H,06bH,003H,080H,007H,080H,
  0fdH,000H,0ffH,003H,000H,004H,000H,007H,000H,004H,
  001H,002H,003H,001H,006H,000H,003H,07fH,001H,07eH,
  001H,07cH,000H,079H,0ffH,07cH,0ffH,07dH,0fdH,000H,
  0faH,000H,00eH,080H,003H,080H,000H,015H,00cH,000H,
  000H,06bH,002H,080H,003H,080H,000H,015H,00aH,000H,
  002H,07fH,001H,07dH,000H,07bH,0ffH,07eH,0feH,07fH,
  0f6H,000H,010H,0f7H,011H,08fH,0ffH,003H,0ffH,002H,
  0feH,001H,0faH,000H,0fdH,07fH,0ffH,07eH,000H,07cH,
  000H,079H,000H,07bH,001H,07eH,003H,000H,006H,000H,
  002H,000H,001H,003H,001H,002H,003H,0fbH,003H,095H,
  00cH,000H,0faH,080H,000H,06bH,009H,080H,003H,095H,
  000H,077H,006H,07aH,006H,006H,000H,009H,0faH,0f1H,
  0faH,07aH,00eH,080H,003H,087H,000H,00bH,002H,002H,
  003H,000H,002H,07eH,001H,002H,004H,000H,002H,07eH,
  000H,075H,0feH,07eH,0fcH,000H,0ffH,001H,0feH,07fH,
  0fdH,000H,0feH,002H,007H,08eH,000H,06bH,009H,080H,
  003H,080H,00eH,015H,0f2H,080H,00eH,06bH,003H,080H,
  003H,095H,000H,06bH,00eH,000H,000H,07dH,0feH,098H,
  000H,06bH,005H,080H,003H,095H,000H,075H,002H,07dH,
  00aH,000H,000H,08eH,000H,06bH,002H,080H,003H,095H,
  000H,06bH,010H,000H,000H,015H,0f8H,080H,000H,06bH,
  00aH,080H,003H,095H,000H,06bH,010H,000H,000H,015H,
  0f8H,080H,000H,06bH,00aH,000H,000H,07dH,002H,083H,
  010H,080H,003H,095H,000H,06bH,009H,000H,003H,002H,
  000H,008H,0fdH,002H,0f7H,000H,00eH,089H,000H,06bH,
  003H,080H,003H,095H,000H,06bH,009H,000H,003H,002H,
  000H,008H,0fdH,002H,0f7H,000H,00eH,0f4H,003H,092H,
  002H,003H,007H,000H,003H,07dH,000H,070H,0fdH,07eH,
  0f9H,000H,0feH,002H,003H,089H,009H,000H,002H,0f5H,
  003H,080H,000H,015H,000H,0f5H,007H,000H,000H,008H,
  002H,003H,006H,000H,002H,07dH,000H,070H,0feH,07eH,
  0faH,000H,0feH,002H,000H,008H,00cH,0f6H,00fH,080H,
  000H,015H,0f6H,000H,0feH,07dH,000H,079H,002H,07eH,
  00aH,000H,0f4H,0f7H,007H,009H,007H,0f7H,003H,08cH,
  001H,002H,001H,001H,005H,000H,002H,07fH,001H,07eH,
  000H,074H,000H,086H,0ffH,001H,0feH,001H,0fbH,000H,
  0ffH,07fH,0ffH,07fH,000H,07cH,001H,07eH,001H,000H,
  005H,000H,002H,000H,001H,002H,003H,0feH,004H,08eH,
  002H,001H,004H,000H,002H,07fH,001H,07eH,000H,077H,
  0ffH,07eH,0feH,07fH,0fcH,000H,0feH,001H,0ffH,002H,
  000H,009H,001H,002H,002H,002H,003H,001H,002H,001H,
  001H,001H,001H,002H,002H,0ebH,003H,080H,000H,015H,
  003H,000H,002H,07eH,000H,07bH,0feH,07eH,0fdH,000H,
  003H,080H,004H,000H,003H,07eH,000H,078H,0fdH,07eH,
  0f9H,000H,00cH,080H,003H,08cH,002H,002H,002H,001H,
  003H,000H,002H,07fH,001H,07dH,0feH,07eH,0f9H,07dH,
  0ffH,07eH,000H,07dH,003H,07fH,002H,000H,003H,001H,
  002H,001H,002H,0feH,00dH,08cH,0ffH,002H,0feH,001H,
  0fcH,000H,0feH,07fH,0ffH,07eH,000H,077H,001H,07eH,
  002H,07fH,004H,000H,002H,001H,001H,002H,000H,00fH,
  0ffH,002H,0feH,001H,0f9H,000H,00cH,0ebH,003H,088H,
  00aH,000H,000H,002H,000H,003H,0feH,002H,0faH,000H,
  0ffH,07eH,0ffH,07dH,000H,07bH,001H,07cH,001H,07fH,
  006H,000H,002H,002H,003H,0feH,003H,08fH,006H,077H,
  006H,009H,0faH,080H,000H,071H,0ffH,087H,0fbH,079H,
  007H,087H,005H,079H,002H,080H,003H,08dH,002H,002H,
  006H,000H,002H,07eH,000H,07dH,0fcH,07dH,004H,07eH,
  000H,07dH,0feH,07eH,0faH,000H,0feH,002H,004H,085H,
  002H,000H,006H,0f9H,003H,08fH,000H,073H,001H,07eH,
  007H,000H,002H,002H,000H,00dH,000H,0f3H,001H,07eH,
  003H,080H,003H,08fH,000H,073H,001H,07eH,007H,000H,
  002H,002H,000H,00dH,000H,0f3H,001H,07eH,0f8H,090H,
  003H,000H,008H,0f0H,003H,080H,000H,015H,000H,0f3H,
  002H,000H,006H,007H,0faH,0f9H,007H,078H,003H,080H,
  003H,080H,004H,00cH,002H,003H,004H,000H,000H,071H,
  002H,080H,003H,080H,000H,00fH,006H,077H,006H,009H,
  000H,071H,002H,080H,003H,080H,000H,00fH,00aH,0f1H,
  000H,00fH,0f6H,0f8H,00aH,000H,002H,0f9H,005H,080H,
  0ffH,001H,0ffH,004H,000H,005H,001H,003H,001H,002H,
  006H,000H,002H,07eH,000H,07dH,000H,07bH,000H,07cH,
  0feH,07fH,0faH,000H,00bH,080H,003H,080H,000H,00fH,
  000H,0fbH,001H,003H,001H,002H,005H,000H,002H,07eH,
  001H,07dH,000H,076H,003H,080H,010H,080H,010H,080H,
  010H,080H,010H,080H,010H,080H,010H,080H,010H,080H,
  010H,080H,010H,080H,010H,080H,010H,080H,010H,080H,
  010H,080H,010H,080H,010H,080H,010H,080H,010H,080H,
  010H,080H,010H,080H,010H,080H,010H,080H,010H,080H,
  010H,080H,010H,080H,010H,080H,010H,080H,010H,080H,
  010H,080H,010H,080H,010H,080H,010H,080H,010H,080H,
  010H,080H,010H,080H,010H,080H,010H,080H,010H,080H,
  010H,080H,010H,080H,010H,080H,010H,080H,010H,080H,
  010H,080H,010H,080H,010H,080H,010H,080H,010H,080H,
  010H,080H,00aH,08fH,002H,07fH,001H,07eH,000H,076H,
  0ffH,07fH,0feH,07fH,0fbH,000H,0ffH,001H,0ffH,001H,
  000H,00aH,001H,002H,001H,001H,005H,000H,0f9H,080H,
  000H,06bH,00cH,086H,00dH,08aH,0ffH,003H,0feH,002H,
  0fbH,000H,0ffH,07eH,0ffH,07dH,000H,07bH,001H,07cH,
  001H,07fH,005H,000H,002H,001H,001H,003H,003H,0fcH,
  003H,080H,000H,00fH,000H,0fbH,001H,003H,001H,002H,
  004H,000H,001H,07eH,001H,07dH,000H,076H,000H,08aH,
  001H,003H,002H,002H,003H,000H,002H,07eH,001H,07dH,
  000H,076H,003H,080H,003H,08fH,000H,074H,001H,07eH,
  002H,07fH,004H,000H,002H,001H,001H,001H,000H,08dH,
  000H,06eH,0ffH,07eH,0feH,07fH,0fbH,000H,0feH,001H,
  00cH,085H,003H,08dH,001H,002H,003H,000H,002H,07eH,
  001H,002H,003H,000H,002H,07eH,000H,074H,0feH,07fH,
  0fdH,000H,0ffH,001H,0feH,07fH,0fdH,000H,0ffH,001H,
  000H,00cH,006H,082H,000H,06bH,008H,086H,003H,080H,
  00aH,00fH,0f6H,080H,00aH,071H,003H,080H,003H,08fH,
  000H,073H,001H,07eH,007H,000H,002H,002H,000H,00dH,
  000H,0f3H,001H,07eH,000H,07eH,003H,082H,003H,08fH,
  000H,079H,002H,07eH,008H,000H,000H,089H,000H,071H,
  002H,080H,003H,08fH,000H,073H,001H,07eH,003H,000H,
  002H,002H,000H,00dH,000H,0f3H,001H,07eH,003H,000H,
  002H,002H,000H,00dH,000H,0f3H,001H,07eH,003H,080H,
  003H,08fH,000H,073H,001H,07eH,003H,000H,002H,002H,
  000H,00dH,000H,0f3H,001H,07eH,003H,000H,002H,002H,
  000H,00dH,000H,0f3H,001H,07eH,000H,07eH,003H,082H,
  003H,08dH,000H,002H,002H,000H,000H,071H,008H,000H,
  002H,002H,000H,006H,0feH,002H,0f8H,000H,00cH,0f6H,
  003H,08fH,000H,071H,007H,000H,002H,002H,000H,006H,
  0feH,002H,0f9H,000H,00cH,085H,000H,071H,002H,080H,
  003H,08fH,000H,071H,007H,000H,003H,002H,000H,006H,
  0fdH,002H,0f9H,000H,00cH,0f6H,003H,08dH,002H,002H,
  006H,000H,002H,07eH,000H,075H,0feH,07eH,0faH,000H,
  0feH,002H,004H,085H,006H,000H,002H,0f9H,003H,080H,
  000H,00fH,000H,0f8H,004H,000H,000H,006H,002H,002H,
  004H,000H,002H,07eH,000H,075H,0feH,07eH,0fcH,000H,
  0feH,002H,000H,005H,00aH,0f9H,00dH,080H,000H,00fH,
  0f7H,000H,0ffH,07eH,000H,07bH,001H,07eH,009H,000H,
  0f6H,0faH,004H,006H,008H,0faH};

END AggGSVText.
PROCEDURE (gsv: gsv_text_ptr)