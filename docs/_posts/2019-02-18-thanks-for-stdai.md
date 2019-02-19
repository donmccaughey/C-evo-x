---
layout: post
title: "Thanks for StdAI!"
---

When I started C-evo-x, there were two big [missing pieces][1]: the installer
project, and the source code for `StdAI.dll`.  I've built installers before, so
creating a [WiX Installer][2] for C-evo-x wasn't hard.  That left the
StdAI source.  [Posting on the C-evo forum][3] confirmed that Steffen never
released the StdAI source.

So I went to the "source of the source" and [asked Steffen directly][4]:

> Hi Steffen,
>
> I started a project at GitHub called "C-evo-x" to bring all the C-evo source
> code together, update it to recent development tools and make it easier to hack
> on.
>
>   https://github.com/donmccaughey/C-evo-x
>
> I've looked through the C-evo site and forums, but I couldn't find the source
> code for StdAI.dll. Would be willing to share that with me and the C-evo
> community?
>
> Thanks for C-evo and the many hours of fun it's given me.
>
> \- Don

Steffen replied the next day, with the StdAI source attached.  I'm adding it to
the C-evo-x repo tonight, in the `StdAI\` directory, and look forward to
integrating it into the build.  Thanks Steffen!

[1]: {{ site.baseurl }}{% post_url 2019-01-13-missing-pieces %}
[2]: {{ site.baseurl }}{% post_url 2019-01-19-wix-installer %}
[3]: http://www.c-evo.org/bb/viewtopic.php?f=6&t=208
[4]: http://steffengerlach.de/contact/

