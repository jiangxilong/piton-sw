\ ========== Copyright Header Begin ==========================================
\ 
\ Hypervisor Software File: device.fth
\ 
\ Copyright (c) 2006 Sun Microsystems, Inc. All Rights Reserved.
\ 
\  - Do no alter or remove copyright notices
\ 
\  - Redistribution and use of this software in source and binary forms, with 
\    or without modification, are permitted provided that the following 
\    conditions are met: 
\ 
\  - Redistribution of source code must retain the above copyright notice, 
\    this list of conditions and the following disclaimer.
\ 
\  - Redistribution in binary form must reproduce the above copyright notice,
\    this list of conditions and the following disclaimer in the
\    documentation and/or other materials provided with the distribution. 
\ 
\    Neither the name of Sun Microsystems, Inc. or the names of contributors 
\ may be used to endorse or promote products derived from this software 
\ without specific prior written permission. 
\ 
\     This software is provided "AS IS," without a warranty of any kind. 
\ ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
\ INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
\ PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED. SUN 
\ MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE FOR 
\ ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR 
\ DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES. IN NO EVENT WILL SUN 
\ OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR 
\ FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE 
\ DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, 
\ ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF 
\ SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
\ 
\ You acknowledge that this software is not designed, licensed or
\ intended for use in the design, construction, operation or maintenance of
\ any nuclear facility. 
\ 
\ ========== Copyright Header End ============================================
id: @(#)device.fth 1.1 07/01/04
purpose: USB device node
copyright: Copyright 2007 Sun Microsystems, Inc. All Rights Reserved
\ See license at end of file

hex
headers

defer make-dev-property-hook  ( speed dev port -- )
' 3drop to make-dev-property-hook

\ Buffers for descriptor manipulation
0 value cfg-desc-buf			\ Configuration Descriptor
0 value dev-desc-buf			\ Device Descriptor
0 value gen-desc-buf			\ Any Descriptor
0 value d$-desc-buf			\ Device String Descriptor
0 value v$-desc-buf			\ Vendor String Descriptor
0 value s$-desc-buf			\ Serial Number String Descriptor

0 value /cfg-desc-buf			\ Length of data in cfg-desc-buf
0 value /dev-desc-buf			\ Length of data in dev-desc-buf
0 value /d$-desc-buf			\ Length of data in d$-desc-buf
0 value /v$-desc-buf			\ Length of data in v$-desc-buf
0 value /s$-desc-buf			\ Length of data in s$-desc-buf

: alloc-pkt-buf  ( -- )
   cfg-desc-buf 0=  if
      /cfg alloc-mem dup to cfg-desc-buf /cfg erase
      /cfg alloc-mem dup to dev-desc-buf /cfg erase
      /cfg alloc-mem dup to gen-desc-buf /cfg erase
      /str alloc-mem dup to d$-desc-buf /str erase
      /str alloc-mem dup to v$-desc-buf /str erase
      /str alloc-mem dup to s$-desc-buf /str erase
   then
;
: free-pkt-buf  ( -- )
   cfg-desc-buf ?dup  if  /cfg free-mem  0 to cfg-desc-buf  then
   dev-desc-buf ?dup  if  /cfg free-mem  0 to dev-desc-buf  then
   gen-desc-buf ?dup  if  /cfg free-mem  0 to gen-desc-buf  then
   d$-desc-buf  ?dup  if  /str free-mem  0 to d$-desc-buf   then
   v$-desc-buf  ?dup  if  /str free-mem  0 to v$-desc-buf   then
   s$-desc-buf  ?dup  if  /str free-mem  0 to s$-desc-buf   then
;

: make-class-properties  ( intf -- )
   dev-desc-buf cfg-desc-buf rot	( dev-buf cfg-buf intf )
   get-class 				( class subclass protocol )
   " protocol" int-property
   " subclass" int-property
   " class"    int-property
;

: make-name-property  ( -- )
   get-class-properties				( class subclass protocol )
   swap rot					( protocol subclass class )
   case
      1  of  2drop " audio"  endof		( name$ )
      2  of  2drop " network"  endof		( name$ )
      3  of  case
             1  of  case
                      1  of  " keyboard"  endof
                      2  of  " mouse"  endof
		      4  of  " joystick"  endof
		      5  of  " gamepad"  endof
		      39 of  " hatswitch"  endof
                      ( default )  " device" rot
                    endcase
                    endof
             ( default ) nip " hid" rot
             endcase
             endof
      7  of  2drop " printer"  endof		( name$ )
      8  of  case
             1  of  drop " flash"  endof
             2  of  drop " cdrom"  endof
             3  of  drop " tape"  endof
             4  of  drop " floppy"  endof
             5  of  drop " storage"  endof
             6  of  drop " storage"  endof
             ( default ) nip " storage" rot
             endcase
             endof
      9  of  2drop " hub"  endof		( name$ )
      ( default )  nip nip " device" rot	( name$ )
   endcase
   device-name
;

: make-vendor-properties  ( -- )
   dev-desc-buf get-vid			( vendor product rev )
   " release"   int-property
   " device-id" int-property
   " vendor-id" int-property
;

\ A little tool so "make-compatible-property" reads better
0 value sadr
0 value slen
: +$  ( add$ -- )
   sadr slen 2swap encode-string encode+  to slen  to sadr
;
: usb,class#>     ( n -- )  " usb,class" $hold  0 u#> ;     \ Prepends: usb,class
: #usb,class#>    ( n -- )  u#s drop  usb,class#>  ;        \ Prepends: usb,classN
: usbif#>         ( n -- )  " usbif" $hold  0 u#> ;         \ Prepends: usbif
: #usbif#>        ( n -- )  u#s drop  usbif#>  ;            \ Prepends: usbifN
: usbif,class#>   ( n -- )  " usbif,class" $hold  0 u#> ;   \ Prepends: usbif,class
: #usbif,class#>  ( n -- )  u#s drop  usbif,class#>  ;      \ Prepends: usbif,classN
: #class,         ( n -- )  u#s drop " ,class" $hold  ;     \ Prepends: class,N

: make-compatible-property  ( -- )
   0 0 encode-bytes  to slen  to sadr		\ Initial empty string

   push-hex

   get-vendor-properties			( vendor product rev )
   3dup      <# #. #, #usb#>  +$		( v p r )	\ usbV,product.rev
   drop 2dup <#    #, #usb#>  +$		( v p )		\ usbV,product
   drop						( vendor )

   get-class-properties				( vendor class subclass protocol )
   2 pick 0<>  if       			( vendor class subclass protocol )
      class-in-dev?  if
         4dup          <# #. #. #class, #usb#>         +$  ( v c s p )  \ usbV,classC.S.P
         4dup  drop    <#    #. #class, #usb#>         +$  ( v c s p )  \ usbV,classC,S
         4dup 2drop    <#       #class, #usb#>         +$  ( v c s p )  \ usbV,classC
         3dup          <# #. #.         #usb,class#>   +$  ( v c s p )  \ usb,classC.S.P
         2 pick 2 pick <# #.            #usb,class#>   +$  ( v c s p )  \ usb,classC,S
         2 pick        <#               #usb,class#>   +$  ( v c s p )  \ usb,classC
      else
         4dup          <# #. #. #class, #usbif#>       +$  ( v c s p )  \ usbifV,classC.S.P
         4dup  drop    <#    #. #class, #usbif#>       +$  ( v c s p )  \ usbifV,classC,S
         4dup 2drop    <#       #class, #usbif#>       +$  ( v c s p )  \ usbifV,classC
         3dup          <# #. #.         #usbif,class#> +$  ( v c s p )  \ usbif,classC.S.P
         2 pick 2 pick <# #.            #usbif,class#> +$  ( v c s p )  \ usbif,classC,S
         2 pick        <#               #usbif,class#> +$  ( v c s p )  \ usbif,classC
      then
   then						( vendor class subclass protocol )
   4drop					( )
   " usb,device"  +$
   sadr slen  " compatible"  property
   pop-base
;

: make-string-properties  ( -- )
   v$-desc-buf /v$-desc-buf " vendor$" str-property
   d$-desc-buf /d$-desc-buf " device$" str-property
   s$-desc-buf /s$-desc-buf " serial$" str-property
;

: make-misc-properties  ( -- )
   cfg-desc-buf 5 + c@ " configuration#" int-property
;

: register-pipe  ( pipe size -- )
   swap h# 0f and 				( size pipe' )
   " assigned-address" get-my-property  0=  if
      decode-int nip nip di-maxpayload!		( )
   else
      2drop
   then
;

: make-ctrl-pipe-property  ( pipe size interval -- )
   drop 2dup register-pipe		( pipe size )
   over h# f and rot h# 80 and  if	( size pipe )
      " control-in-pipe"  int-property
      " control-in-size"
   else
      " control-out-pipe" int-property
      " control-out-size"
   then  int-property
;
: make-iso-pipe-property  ( pipe size interval -- )
   drop 2dup register-pipe		( pipe size )
   over h# 0f and rot h# 80 and  if	( size pipe )
      " iso-in-pipe"  int-property
      " iso-in-size"
   else
      " iso-out-pipe" int-property
      " iso-out-size"
   then  int-property
;
: make-bulk-pipe-property  ( pipe size interval -- )
   drop 2dup register-pipe		( pipe size )
   over h# f and rot h# 80 and  if	( size pipe )
      " bulk-in-pipe"  int-property
      " bulk-in-size"
   else
      " bulk-out-pipe" int-property
      " bulk-out-size" 
   then  int-property
;
: make-intr-pipe-property  ( pipe size interval -- )
   -rot 2dup register-pipe rot	( pipe size interval )
   rot dup h# f and swap h# 80 and  if	( size interval pipe )
      " intr-in-pipe"      int-property
      " intr-in-interval"  int-property
      " intr-in-size"
   else
      " intr-out-pipe"     int-property
      " intr-out-interval" int-property
      " intr-out-size"
   then  int-property
;
: make-pipe-properties  ( adr -- )
   dup c@ over + swap 4 + c@ 		( adr' #endpoints )
   swap ENDPOINT find-desc swap 0  ?do	( adr' )
      dup 2 + c@			( adr pipe )
      over 4 + le-w@			( adr pipe size )
      2 pick 6 + c@			( adr pipe size interval )
      3 pick 3 + c@ 3 and  case		( adr pipe size interval type )
         0  of  make-ctrl-pipe-property  endof
         1  of  make-iso-pipe-property   endof
         2  of  make-bulk-pipe-property  endof
         3  of  make-intr-pipe-property  endof
      endcase
      dup c@ +				( adr' )
   loop  drop
;

: make-descriptor-properties  ( intf -- )
   dup make-class-properties		\ Must make class properties first
   make-name-property			( intf )
   make-vendor-properties		( intf )
   make-compatible-property		\ Must come after vendor and class
   make-string-properties		( intf )
   cfg-desc-buf swap find-intf-desc 	( adr )
   make-pipe-properties 		( )
   make-misc-properties
;

: make-common-properties  ( dev -- )
   1 " #address-cells" int-property
   0 " #size-cells"    int-property
   \ SUN Note - Modified for single-cell unit-address
   my-space encode-phys " reg" property		\ my-space=port
   dup " assigned-address" int-property
   ( dev ) di-speed@  case
      speed-low  of  " low-speed"   endof
      speed-full of  " full-speed"  endof
      ( default )  " high-speed" rot
   endcase
   0 0 2swap str-property
;

: make-combined-node  ( dev port -- )
   dup >r encode-unit " " 2swap  new-device set-args	( dev )( R: port )
   dup dup di-speed@ swap r> make-dev-property-hook		( dev )
   make-common-properties		\ Make non-descriptor based properties
   0 make-descriptor-properties		\ Combined has single interface, use 0.
   load-fcode-driver			\ Find and load fcode driver
   finish-device
;

\ Get all the descriptors we need in making properties now because target is
\ questionable in the child's context.

h# 409 constant language  			\ Unicode id
: get-string ( lang idx adr -- actual )
   over 0=  if  3drop  0 exit  then		\ No string index
   -rot get-str-desc
;
: get-str-descriptors  ( -- )
   language					( lang )
   dup dev-desc-buf d# 14 + c@ v$-desc-buf get-string to /v$-desc-buf
   dup dev-desc-buf d# 15 + c@ d$-desc-buf get-string to /d$-desc-buf
       dev-desc-buf d# 16 + c@ s$-desc-buf get-string to /s$-desc-buf
;
: refresh-desc-bufs  ( -- )
   dev-desc-buf 12 get-dev-desc to /dev-desc-buf		\ Refresh dev-desc-buf
   cfg-desc-buf  0 get-cfg-desc to /cfg-desc-buf		\ Refresh cfg-desc-buf
   get-str-descriptors
;

: set-maxpayload  ( dev -- )
   dev-desc-buf /pipe0 get-dev-desc  if
      dev-desc-buf 7 + c@ 0 rot di-maxpayload!
   else
      drop
   then
;


: make-device-node  ( port dev -- )
   dup set-maxpayload			( port dev )
   cfg-desc-buf 0 get-cfg-desc dup to /cfg-desc-buf
   0=  if  2drop  exit  then
   swap					( dev port )
   cfg-desc-buf 4 + c@ 			( dev port ifaces )
   dup 1 = if
      \ Create a combined node
      drop over set-target		( dev port )	\ Refresh target
      refresh-desc-bufs			( dev port )
      make-combined-node		( )		\ one-based port#

   else					( dev port ifaces )
      \ Create a device node and interface nodes
      over encode-unit " " 2swap new-device set-args	( dev port ifaces )

      \ Create generic "device" properties and bring in generic device driver
      " device" encode-string " name" property
      " usbdevice" encode-string " compatible" property
      2 encode-int " #address-cells" property
      0 encode-int " #size-cells" property
      over encode-int " reg" property	( dev port ifaces )

      load-fcode-driver			( dev port ifaces )


      \ Loop creating each interface under device node
      ( ifaces ) 0 ?do			( dev port )
         over set-target		\ Refresh target
         refresh-desc-bufs		( dev port )
         0 i " encode-unit" $call-self	( dev port $unit-address )
         " " 2swap new-device set-args	( dev port )
         dup >r over dup di-speed@ swap r> make-dev-property-hook
	 my-address my-space encode-phys " reg" property
	 over " assigned-address" int-property  ( dev port )
	 over  di-speed@  case		  ( dev port )
	    speed-low  of  " low-speed"   endof
	    speed-full of  " full-speed"  endof
	    ( default )  " high-speed" rot
	 endcase			( dev port $speed )
	 0 0 2swap str-property		( dev port )
         my-space make-descriptor-properties \ Make descriptor based properties
         load-fcode-driver		\ Find and load fcode driver
         finish-device			( dev port )
      loop				( dev port )
      2drop				( )
      finish-device
   then
;

headers

\ LICENSE_BEGIN
\ Copyright (c) 2006 FirmWorks
\ 
\ Permission is hereby granted, free of charge, to any person obtaining
\ a copy of this software and associated documentation files (the
\ "Software"), to deal in the Software without restriction, including
\ without limitation the rights to use, copy, modify, merge, publish,
\ distribute, sublicense, and/or sell copies of the Software, and to
\ permit persons to whom the Software is furnished to do so, subject to
\ the following conditions:
\ 
\ The above copyright notice and this permission notice shall be
\ included in all copies or substantial portions of the Software.
\ 
\ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
\ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
\ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
\ NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
\ LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
\ OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
\ WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
\
\ LICENSE_END
