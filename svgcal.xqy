xquery version "1.0-ml";

(: See http://github.com/marklogic/ml-rest-lib if you're still on 4.x :)
import module namespace rest="http://marklogic.com/appservices/rest"
       at "/MarkLogic/appservices/utils/rest.xqy";

import module namespace ce="http://nwalsh.com/xmlns/xquery/calevents"
       at "calevents.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";
declare default element namespace "http://www.w3.org/2000/svg";

declare namespace pg="http://nwalsh.com/xmlns/pageinfo";
declare namespace f="http://nwalsh.com/xmlns/xquery/functions";

declare option xdmp:mapping "false";

(: Description of the endpoint :)
declare variable $endpoint as element(rest:request)
  := <request xmlns="http://marklogic.com/appservices/rest"
              uri="^/svgcal" endpoint="/PIM/MLS/svgcal.xqy" user-params="forbid">
       <param name="date" as="date"/>
       <param name="paper"
              values="{string-join($PAPERINFO/pg:paper/@name,'|')}"
              default="{$PAPERINFO/pg:paper[1]/@name}"/>
       <param name="weekstart" values="sunday|monday" default="sunday"/>
       <param name="corner" values="ur|ul|lr|ll" default="ll"/>
       <param name="scale" as="decimal" default="1.0"/>
       <param name="debug" as="boolean" default="false"/>
       (: make this "true" by default if you provide your own calevents.xqy :)
       <param name="showevents" as="boolean" default="false"/>
       <param name="image"/>
     </request>;

(: If we were being nice, we'd catch exceptions and pretty up the errors.
   We're not being nice, we're being lazy. :)
declare variable $params := rest:process-request($endpoint);

(: We generate the calendar at 300dpi for convenience; SVG is scalable. :)
declare variable $RES := 300;

(: You can add your own paper sizes here... :)
declare variable $PAPERINFO as element(pg:papers)
  := <papers xmlns="http://nwalsh.com/xmlns/pageinfo">
       <paper name="letter" width="8.5in" height="11in" margin="0.25in">
         <month family="Times New Roman" size="22pt" opacity="0.5" fill="white" style="italic"/>
         <weekday family="Times New Roman" size="10pt"/>
         <day family="Times New Roman" size="10pt"/>
         <nonday family="Times New Roman" size="10pt" opacity="0.35" style="italic"/>
         <event family="Times New Roman" size="8pt"/>
         <nonevent family="Times New Roman" size="8pt" opacity="0.35" style="italic"/>
       </paper>
       <paper name="legal" width="8.5in" height="14in" margin="0.25in">
         <month family="Times New Roman" size="22pt" opacity="0.5" fill="white" style="italic"/>
         <weekday family="Times New Roman" size="10pt"/>
         <day family="Times New Roman" size="10pt"/>
         <nonday family="Times New Roman" size="10pt" opacity="0.35" style="italic"/>
         <event family="Times New Roman" size="8pt"/>
         <nonevent family="Times New Roman" size="8pt" opacity="0.35" style="italic"/>
       </paper>
       <paper name="a4" width="210mm" height="297mm" margin="0.25in">
         <month family="Times New Roman" size="22pt" opacity="0.5" fill="white" style="italic"/>
         <weekday family="Times New Roman" size="10pt"/>
         <day family="Times New Roman" size="10pt"/>
         <nonday family="Times New Roman" size="10pt" opacity="0.35" style="italic"/>
         <event family="Times New Roman" size="8pt"/>
         <nonevent family="Times New Roman" size="8pt" opacity="0.35" style="italic"/>
       </paper>
       <paper name="4x6" width="4in" height="6in" margin="1mm">
         <month family="Times New Roman" size="10pt" opacity="0.5" fill="white" style="italic"/>
         <weekday family="Times New Roman" size="8pt" opacity="0.5" fill="white"/>
         <day family="Times New Roman" size="8pt"/>
         <nonday family="Times New Roman" size="8pt" opacity="0.35" style="italic"/>
         <event family="Times New Roman" size="0"/>
         <nonevent family="Times New Roman" size="0" opacity="0.35" style="italic"/>
       </paper>
     </papers>;

declare variable $PAPERWIDTHS as map:map
  := let $map := map:map()
     let $_ := for $paper in $PAPERINFO/pg:paper
               return
                 map:put($map, string($paper/@name), f:dimension($paper/@width))
     return $map;

declare variable $PAPERHEIGHTS as map:map
  := let $map := map:map()
     let $_ := for $paper in $PAPERINFO/pg:paper
               return
                 map:put($map, string($paper/@name), f:dimension($paper/@height))
     return $map;

declare variable $PAPER := $PAPERINFO/pg:paper[@name = map:get($params, 'paper')];

(: Fill styles :)
declare variable $GRIDSTYLE
  := "stroke:rgb(99,99,99);stroke-width:1px;fill:none;";
declare variable $WEEKENDFILLSTYLE := "fill:blue;fill-opacity:0.1";
declare variable $HOLIDAYFILLSTYLE := "fill:red;fill-opacity:0.1";
declare variable $BACKGROUNDFILL := "white";

declare variable $WEEKDOWSTYLE  := f:text-style($PAPER/pg:weekday);
declare variable $WEEKDAYSTYLE  := f:text-style($PAPER/pg:day);
declare variable $NONDAYSTYLE  := f:text-style($PAPER/pg:nonday);
declare variable $EVENTSTYLE    := f:text-style($PAPER/pg:event);
declare variable $NONEVENTSTYLE    := f:text-style($PAPER/pg:nonevent);
declare variable $MONTHSTYLE    := f:text-style($PAPER/pg:month);

declare variable $PAPERWIDTH  := map:get($PAPERWIDTHS, map:get($params, "paper"));
declare variable $PAPERHEIGHT := map:get($PAPERHEIGHTS, map:get($params, "paper"));

declare variable $MARGIN    := f:dimension($PAPER/@margin);
declare variable $WEEKSTART := if (map:get($params, "weekstart") = "sunday") then 0 else 1;
declare variable $WEEKS     := 5 + $WEEKSTART;

declare variable $CALWIDTH := round(($PAPERWIDTH - ($MARGIN * 2)) div 7) * 7;
declare variable $CALHEIGHT
  := min(($RES, round((($PAPERHEIGHT div 2) - ($MARGIN * 2)) div $WEEKS))) * $WEEKS;

declare variable $IMGWIDTH := $CALWIDTH;
declare variable $IMGHEIGHT := $PAPERHEIGHT - ($CALHEIGHT + ($MARGIN * 3));

declare variable $XORIG := floor(($PAPERWIDTH - $CALWIDTH) div 2);
declare variable $YORIG := floor($PAPERHEIGHT - ($CALHEIGHT + $MARGIN));
declare variable $XOFS := 100;
declare variable $YOFS := 1800;
declare variable $DAYWIDTH := $CALWIDTH div 7;
declare variable $DAYHEIGHT := $CALHEIGHT div $WEEKS;

declare variable $DAYS
  := (if (map:get($params, "weekstart") = "sunday") then "Sun" else (),
      "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun");

declare variable $MONTHS := ("January","February","March","April","May","June",
                             "July","August","September","October","November","December");

declare variable $CALDATE as xs:date
  := let $pdate := (map:get($params, "date"), current-date())[1]
     let $fdate := concat(substring(string($pdate), 1, 8), "01")
     return
       xs:date($fdate);

declare variable $DATESARRAY as xs:date+
  :=  let $first    := f:weekday-from-date($CALDATE)
      let $precdays := (if ($WEEKSTART = 1) then 6 else (), 0, 1, 2, 3, 4, 5, 6)
      let $prec     := $precdays[$first + 1]
      for $day in (0 - $prec to $WEEKS * 7)
      let $durstr   := concat(if ($day >= 0) then "P" else "-P", abs($day), "D")
      let $duration := xs:dayTimeDuration($durstr)
      return
        $CALDATE + $duration;

(: ====================================================================== :)

declare function f:dimension(
  $dim as xs:string
) as xs:float
{
  let $units := replace($dim, "(^[0-9\.]+)\s*(.*)$", "$2")
  let $magnitude := replace($dim, "(^[0-9\.]+)\s*(.*)$", "$1")
  return
    if ($units = "pt")
    then round(xs:float(xs:decimal($magnitude) div 72) * $RES)
    else if ($units = "mm")
    then round(xs:float(xs:decimal($magnitude) div 25.4) * $RES)
    else if ($units = "cm")
    then round(xs:float(xs:decimal($magnitude) div 2.54) * $RES)
    else round(xs:decimal($magnitude) * $RES) (: assume inches :)
};

declare function f:text-style(
  $desc as element()
) as xs:string
{
  let $opacity := ($desc/@opacity, "1.0")[1]
  let $family  := ($desc/@family, "Times New Roman")[1]
  let $size    := f:dimension(($desc/@size, "10pt")[1])
  let $fill    := ($desc/@fill, "black")[1]
  let $style   := ($desc/@style, "normal")[1]
  let $weight  := ($desc/@weight, "medium")[1]
  return
    string-join(
      (concat("font-family: &quot;", $family, "&quot;"),
       concat("font-size: ", $size),
       concat("font-weight: ", $weight),
       concat("font-style: ", $style),
       concat("fill: ", $fill),
       concat("opacity: ", $opacity)), ";")
};

declare function f:weekday-from-date($date as xs:date) {
  (: Dec 31, 1899 was a Sunday; Sunday = 0, Monday = 1, etc... :)
  let $dec-31-1899 := xs:date("1899-12-31")
  let $duration := $date - $dec-31-1899
  let $days := days-from-duration($duration)
  return
    if ($days < 0)
    then
      if ($days mod 7 = 0) then 0 else 7 + ($days mod 7)
    else
      $days mod 7
};

declare function f:day-of-month(
  $row as xs:int,
  $col as xs:int
) as element()+
{
  let $ofs  := (($row - 1) * 7) + $col - 1
  let $date := $DATESARRAY[$ofs + 1]
  let $num  := day-from-date($date)
  let $x    := (($col - 1) * $DAYWIDTH) + $XORIG + 25
  let $y    := (($row - 1) * $DAYHEIGHT) + $YORIG + 60
  return
    (<text x="{$x}" y="{$y}"
           style="{ if (month-from-date($date) = month-from-date($CALDATE))
                    then $WEEKDAYSTYLE
                    else $NONDAYSTYLE }">
       { if ($num < 10)
         then <tspan opacity="0.0">0</tspan>
         else ()
       }
       <tspan>
         { $num }
       </tspan>
     </text>,
     if (map:get($params, "showevents") and ce:holiday($date))
     then
       <rect x='{$XORIG + (($col - 1) * $DAYWIDTH)}'
             y='{$YORIG + (($row - 1) * $DAYHEIGHT)}'
             width='{$DAYWIDTH}' height='{$DAYHEIGHT}'
             style="{$HOLIDAYFILLSTYLE}"/>
     else
       ())
};

declare function f:events(
  $row as xs:int,
  $col as xs:int
) as element()*
{
  let $ofs     := (($row - 1) * 7) + $col - 1
  let $date    := $DATESARRAY[$ofs + 1]
  let $events  := if (map:get($params, "showevents")) then ce:events($date) else ()
  let $ecount
    := xs:integer(floor($DAYHEIGHT div (f:dimension($PAPER/pg:event/@size) * 1.5)) - 1)
  for $event at $index in $events[1 to $ecount]
  let $x := (($col - 1) * $DAYWIDTH) + $XORIG + 25
  let $y := (($row - 1) * $DAYHEIGHT) + $YORIG + 60 + (($index - 1) * 35) + 60
  return
    (<clipPath id="clip-{$x}-{$y}">
       <rect x="{$x}" y="{$y - 50}" width="{$DAYWIDTH - 40}" height="100"/>
     </clipPath>,
     <text x='{$x}' y='{$y}' clip-path="url(#clip-{$x}-{$y})"
           style="{ if (month-from-date($date) = month-from-date($CALDATE))
                    then $EVENTSTYLE
                    else $NONEVENTSTYLE }">
       { $event }
     </text>)
};

let $trace := xdmp:log(concat($PAPER/@name, " ", $IMGWIDTH, "x", $IMGHEIGHT))
return
  <svg xmlns="http://www.w3.org/2000/svg"
       xmlns:xlink="http://www.w3.org/1999/xlink"
       version="1.1"
       width="{f:dimension($PAPER/@width)}px" height="{f:dimension($PAPER/@height)}px"
       viewBox="0 0 {f:dimension($PAPER/@width)} {f:dimension($PAPER/@height)}">

    <g transform="scale({map:get($params, 'scale')})">

      { if (map:get($params, "debug"))
        then
          <path d="M 0 0 h {$PAPERWIDTH} v {$PAPERHEIGHT} h -{$PAPERWIDTH} v -{$PAPERHEIGHT}"
                style="stroke:rgb(255,0,0);stroke-width:1px;fill:{$BACKGROUNDFILL};"/>
        else
          <path d="M 0 0 h {$PAPERWIDTH} v {$PAPERHEIGHT} h -{$PAPERWIDTH} v -{$PAPERHEIGHT}"
                style="stroke:none;fill:{$BACKGROUNDFILL};"/>
      }

      <!-- grid for calendar -->
      <path style="{$GRIDSTYLE}">
        { attribute { fn:QName("", "d") }
                    { string-join(
                        (for $line in (1 to ($WEEKS+1))
                         return
                           ("M",
                            string($XORIG),
                            string($YORIG + ($line - 1) * $DAYHEIGHT),
                            "h",
                            string($CALWIDTH)),
                        for $line in (1 to 8)
                        return
                          ("M",
                           string($XORIG + ($line - 1) * $DAYWIDTH),
                           string($YORIG),
                           "v",
                           string($CALHEIGHT))),
                        " ")
                    }
        }
      </path>

      { if (string(map:get($params, "image")) != '')
        then
          <image x="{$XORIG}" y="{$XORIG}" width="{$IMGWIDTH}" height="{$IMGHEIGHT}"
                 xlink:href="{map:get($params, 'image')}"/>
        else
          <text x="{$XORIG}" y="{$XORIG + f:dimension($PAPER/pg:weekday/@size)}"
                style="{$WEEKDAYSTYLE}">
            { concat("Use 'image' parameter to place ",
                     $IMGWIDTH, "x", $IMGHEIGHT,
                     " image here") }
          </text>
      }

      { for $day in (1 to 7)
        let $name := substring($DAYS[$day], 1, 3)
        let $x := $XORIG + ($DAYWIDTH * ($day - 1)) + ($DAYWIDTH div 2)
        let $y := $YORIG - 18
        return
          <text x="{$x}"  y="{$y}" text-anchor="middle" style="{$WEEKDOWSTYLE}">
            { string($name) }
          </text>
      }

      { if ($WEEKSTART = 0)
        then
          (<rect x='{$XORIG}' y='{$YORIG}' width='{$DAYWIDTH}' height='{$CALHEIGHT}'
                 style="{$WEEKENDFILLSTYLE}"/>,
           <rect x='{$XORIG + ($DAYWIDTH*6)}' y='{$YORIG}'
                 width='{$DAYWIDTH}' height='{$CALHEIGHT}'
                 style="{$WEEKENDFILLSTYLE}"/>)
        else
           <rect x='{$XORIG + ($DAYWIDTH*5)}' y='{$YORIG}'
                 width='{$DAYWIDTH * 2}' height='{$CALHEIGHT}'
                 style="{$WEEKENDFILLSTYLE}"/>
      }

      { for $row in (1 to $WEEKS)
        for $col in (1 to 7)
        return
          (f:day-of-month($row, $col),
           if ($PAPER/pg:event/@size = "0")
           then
             ()
           else
             f:events($row, $col))
      }

      <text style="{$MONTHSTYLE}">
        { let $corner := map:get($params, "corner")
          let $fontsize := f:dimension($PAPER/pg:month/@size)
          let $em := $fontsize
          let $halfem := round($fontsize div 2)
          let $x := if ($corner = "ul" or $corner = "ll")
                    then $XORIG + $halfem
                    else $XORIG + $IMGWIDTH - $halfem
          let $y := if ($corner = "ur" or $corner = "ul")
                    then $YORIG - ($IMGHEIGHT + $MARGIN) + $em + $halfem
                    else $YORIG - (2 * $MARGIN)
          let $a := if ($corner = "ul" or $corner = "ll")
                    then "start"
                    else "end"
          return
            (attribute { fn:QName("", "x") } { $x },
             attribute { fn:QName("", "y") } { $y },
             attribute { fn:QName("", "text-anchor") } { $a })
        }
        { concat($MONTHS[month-from-date($CALDATE)], ", ", year-from-date($CALDATE)) }
      </text>
    </g>
  </svg>
