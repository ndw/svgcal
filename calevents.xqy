xquery version "1.0-ml";

module namespace ce="http://nwalsh.com/xmlns/xquery/calevents";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

declare function ce:events(
  $date as xs:date
) as xs:string*
{
  for $int in (10 to xdmp:random(16))
  return
    "Random event"
};

declare function ce:holiday(
  $date as xs:date
) as xs:boolean
{
  xdmp:random(30) < 3
};
