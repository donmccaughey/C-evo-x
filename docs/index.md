---
title: "C-evo-x Docs"
---

# C-evo-x Docs

C-evo-x is a fork of [C-evo][11] 1.2.0, a freeware empire building game for
Windows by [Steffen Gerlach][12].  C-evo and C-evo-x are in the 
[public domain][13].

[11]: http://c-evo.org
[12]: http://www.steffengerlach.de
[13]: https://github.com/donmccaughey/C-evo-x/blob/master/LICENSE

The goal of the C-evo-x project is to modernize and maintain C-evo, making the
game more modular and the code more approachable.

 - [The Protocol](./protocol)
 - [Resource Files](./resource_files)
 - [Versions](./versions)

## Dev Journal

{% for post in site.posts limit:3 %}
- {{ post.date | date_to_string }}: [{{ post.title }}]({{ post.url | absolute_url }})

    > {{ post.excerpt }}

{% endfor %}

<div class='post_nav'>
    <a class='next' href='dev-journal/'>all posts &gt;&gt;</a>
</div>

