The Puppet Type System
===

In Puppet 3.5's future parser there is a new type system that makes it much easier to
write validation logic for parameters. I have written a series of blog posts about
the new type system - and this post is just an index to the series.

It works best if they are read in the order they were published:

* [What Type of Type are you][1] - introduction
* [Type Hierarchy and Scalars][2] - the basic types and overview of all types
* [Lets talk about Undef][3] - about undefined, emptiness and collections
* [Variant, Data, and Type - and a bit of Type Theory][4]
* [Class and Resource Types][5]
* [Operations on Type][6]
* [Adding Struct and Tuple][7] - two late additions to the type system

[1]:http://puppet-on-the-edge.blogspot.se/2013/12/what-type-of-type-are-you.html
[2]:http://puppet-on-the-edge.blogspot.se/2013/12/the-type-hierarchy-and-literals.html
[3]:http://puppet-on-the-edge.blogspot.se/2013/12/lets-talk-about-undef.html
[4]:http://puppet-on-the-edge.blogspot.se/2013/12/variant-data-and-type-and-bit-of-type.html
[5]:http://puppet-on-the-edge.blogspot.se/2013/12/class-and-resource-types.html
[6]:http://puppet-on-the-edge.blogspot.se/2013/12/operating-on-types.html
[7]:http://puppet-on-the-edge.blogspot.se/2014/02/adding-struct-and-tuple-to-puppet-type.html

I will update this index blog post where there are new posts in the series. Also, if there are changes to the implementation, I will try to keep the blog posts updated.

### Future Posts

I was asked questions about how the type system can be used from Ruby, and I plan to write a
post about that the next time I am waiting for paint to dry...