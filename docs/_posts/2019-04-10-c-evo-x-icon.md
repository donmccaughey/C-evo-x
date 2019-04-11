---
layout: post
title: "C-evo-x Icon"
---

The logo and application icon for C-evo is a picture of the Earth in the center
of four stylized compass points.  The Windows icon, `cevoxp2.ico`, only contains
a 32 x 32 pixel version, though it _is_ 32-bit color.

![C-evo Icon]({{ "/dev-journal/2019-04-10-c-evo-x-icon-cevoxp2.ico" |
relative_url }})

The file name makes me suspect that it dates back to the early days of C-evo,
when Windows XP was king.  Even then, Microsoft [recommended that you
provide][1] 16x16, 32x32 and 48x48 pixel icons in 4-bit, 8-bit and 32-bit color.
Windows Vista [added for 256x256 pixel icons][2] to support high-dpi displays.
I hate to leave gaps that aren't filled in, and the single resolution icon is
one of those gaps.

In addition to the icon, there's a high resolution version of the C-evo logo
included in the game's `Graphics\` directory.

![C-evo Logo]({{ "/dev-journal/2019-04-10-c-evo-x-icon-Background.png" |
relative_url }})

The compass points in this version are bigger relative to the Earth than in the
icon version, and you can see embossed scenes on each point.

I'm not much of an artist, and my knowledge of design tools like Photoshop and
Illustrator is minimal.  The best I could do would be to scale the existing
32x32 pixel icon up (but Windows does that automatically) or try to scale the
full-sized logo down (but a naieve scaling would look like crap).  Neither
seemed like a fun task for me, and I'm pretty certain I'd always be unhappy with
the results.

So I decided to spend a little money and see if I could hire an artist to create
a new icon for C-evo-x.  There are a number of sites where you can put your
requirements up and ask designers to submit proposals.  I tried out
[DesignCrowd][3] mainly because they clearly listed "Icon Design" as a project
type.  Their site looked professional and established, and creating my project
was straightforward; my only criticism being the relentless calls to spend just
a little more money at every turn (_get more designs!_, _attract more
designers!_, _upgrade your project!_).

Here's the brief for my DesignCrowd project:

> C-evo is an open source empire building game for Windows. "C-evo-x" is my fork
> of the project; the "-x" is "extended", "expanded", "extreme", etc. The original
> author hasn't updated C-evo in five years, so I've started my "C-evo-x" project
> to update the game. You can see the original game website at
> http://www.c-evo.org and my project site at
> https://github.com/donmccaughey/C-evo-x. I'm a good programmer but a terrible
> artist, so I need professional help to create a new icon for the game. The
> original icon / logo is a view of the Earth against four stylized compass points
> (see attached examples). I'd like something that is a clear descendant of the
> original design. An obvious variation is to rotate the compass points into an
> "X". I'm also open to other designs and color palettes.The game runs on Windows,
> so I need a Windows application .ico file with 16x16, 32x32, 48x48, and 256x256
> resolution icons. The best official guide to Windows app icons I could find is
> here: https://docs.microsoft.com/en-us/windows/desktop/uxguide/vis-icons . I'd
> also like a 1024x1024 res transparent PNG for use on the game's project site.

A week later, I had ten different designs from eight different designers.  Of
the ten, I liked four of them, but one really stood out.  All the artists liked
the idea of rotating the compass points into an "X", but the winner,
[an1state][4], picked up on the details from the original high-res C-evo logo
and added some nice "Civ" elements to the compass points.

![C-evo-x icon]({{ "/dev-journal/2019-04-10-c-evo-x-icon-icon-sizes.png"
| relative_url }})

And even better, I have the original _Illustrator_ file for future use, and
anistate also gave me a nice SVG version of the logo, which now adorns the
sidebar of this site.

[1]: https://docs.microsoft.com/en-us/previous-versions/ms997636(v=msdn.10)
[2]: https://docs.microsoft.com/en-us/windows/desktop/uxguide/vis-icons
[3]: https://www.designcrowd.com
[4]: https://designers.designcrowd.com/designer/799178/an1state

