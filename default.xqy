xquery version "1.0-ml";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

<html>
<head>
<title>SVG Calendar</title>
</head>
<body>
<h1>SVG Calendar</h1>

<form method="get" action="/svgcal.xqy">
<p>This form lets you set the calendar options.</p>
<p>Make a calendar for
<input name="date" type="text"
       value="{substring(string(current-date()), 1, 10)}"/>
on <select name="paper">
<option value="letter">US Letter</option>
<option value="a4">A4</option>
<option value="legal">US Legal</option>
<option value="4x6">4x6</option>
</select> paper with weeks that start
on <select name="weekstart">
<option value="sunday">Sunday</option>
<option value="monday">Monday</option>
</select>.</p>

<p>The calendar image comes from
<input size="60" name="image" placeholder="uri"/>.
</p>

<p>Put the month and year in the <select name="corner">
<option value="ul">upper-left</option>
<option value="ur">upper-right</option>
<option value="ll">lower-left</option>
<option value="lr">lower-right</option>
</select> corner of the image.</p>

<p>Scale the image by
<input name="scale" value="0.25"/>. (Scaling allows you to adjust the
the calendar so that it fits in the browser window.)</p>

<p>Events are <select name="showevents">
<option value="true">on</option>
<option value="false">off</option></select>. (On this test site, events are
just random; if you install the code locally you can use your own
events.)</p>

<p>Debug <select name="debug">
<option value="true">on</option>
<option value="false">off</option></select>. (Just draws a box around
the calendar.)</p>

<p><input type="submit" value="Draw calendar"/></p>
</form>

<p>See
<a href="https://github.com/ndw/svgcal">https://github.com/ndw/svgcal</a>
for more details.</p>

</body>
</html>
