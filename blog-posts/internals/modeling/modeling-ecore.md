In my three previous posts about Modeling you can read about what a model is and the
technologies used to implement such models, as well as learn about basic modeling with 
RGen - the implementation of Ecore for Ruby.

In this post I am going to take you on a tour of the Ecore model itself. In order for you to be able
to have an idea of where we are when we stop at the interesting sites I am going to give you the
complete map of Ecore up front. However, just like any guided city tour, I am not going to stop and show you every back alley.

A slight feeling of dizziness is excepted since we are at high meta-meta altitude, but it should be alright as long as you look where you step and go back to concrete ground when you are lost.

This post is the most theoretical in the series, and you probably want to come back to it
for reference. I am sorry there are not that many examples, I promise to come back in more
posts with concrete examples where all the meta-magic gets put to good use.

If you want a model to try thing out on, you can use this [Car RGen model][2].

### ECore Model

So here is the ECore model in full glory, thanks to [Ed Merks (creator of Ecore)][11] that produced this very compact while still readable diagram. I post this map here at the beginning so you can jump
back to it for reference - if you immediately want to find the sites of interest on the map, look for `EClass`, `EReference`, and `EAttribute` since they should be somewhat familiar from previous posts.

http://2.bp.blogspot.com/_rFZqMGOSYY8/SF0JlzHrB4I/AAAAAAAAAAs/MdoEmI6CKVw/s1600-h/EcoreOverview.gif

I am going to explain this first from a structural point of view (top-down), and then dive into the interesting details of the various elements.

### Ecore Structure

All definitions in `ECore` live inside an `EPackage` which corresponds to a Ruby Module, or a Java 
Package (or similar concept in other technologies). If you have located the `EPackage` box in the diagram, you see two attributes; `nsURI`, and `nsPrefix` which are used to uniquely identify the model (the "schema identifier" if you like), and a name prefix that is typically used when generating code. You do not have to set these when you just want to model classes and use them at runtime, but
they are valuable in other scenarios.

`EPackage` can be a sub package inside another package (this is rarely used).

An `EPackage` contains `EClassifier` elements and those come in concrete
forms of; `EClass`, and `EDataType`.
You have already seen a glimpse of `EClass` and `EDataType` in the previous posts; `EClass`
is used for the classes in our model, and `EDataType` is used for data types that
we can use in the attributes of classes (e.g. String, Integer).

An `EClass` contains `EStructuralFeature` elements and those come in concrete form of; `EAttribute`, and `EReference`. Again, in the previous posts you saw examples of both attributes and references.

`ECore` can also be used to describe operations (i.e. methods), but since Ecore is not an implementation language, it cannot contain the actual implementation of such operations, only a declaration of them. When using EMF for Java, the code generator will generate method stubs for the operations, and it is easy to fill in the implementation logic. When we use RGen and implement the model in Ruby, we typically do not generate code (although it is possible), and we must instead define the implementation of operations a different way if we get a model where operations are specified (and we want to provide the declared operations - there is no requirement to do so).

And finally, there is support for annotations. Any `EModelElement` can have annotations. RGen (and EMF) does not know what to do with these annotation other than knowing about the association. It is however an important mechanism for tools in a model toolchain, and they are typically used for things like generation  of documentation, defining properties that are of importance for code generation, mark something as deprecated, etc. The use of an `EAnnotation` is often a light weight alternative to defining a completely separate model. There are some known annotation identities, say if we want to generate Java code from a model that we author with the RGen Metamodel Builder, and we would like JavaDoc comments to be generated in the Java source. (That is all that I planned to say about `EAnnotations`).

### EPackage

We get the `EPackage` from our model's Ruby Module:

    MyModel.ecore   # => ECore::EPackage

The interesting operations on EPackage are:

| method                   | description | type
| ---                      | ---         | ---
| `eClasses`               | The `EClasses` defined in this package     | `Enumeration<ECore::EClass>`
| `eClassifiers`           | The `EClassifiers` defined in this package | `Enumeration<ECore::EClassifiers>`
| `eAllClasses`            | The `EClasses` defined in this and all super packages     | `Enumeration<ECore::EClass>`
| `eAllClassifiers`           | The `EClassifiers` defined in this package and all super packages | `Enumeration<ECore::EClassifiers>`

Remember that we are using a model; the `ECore` model, and we can naturally manipulate this model like any other model.
In fact, we can build the model using Ruby logic, and then generate the implementation on the fly if we want. Thus, in addition to the methods shown above, there are methods to add and remove
classifiers, and to get/set the attributes of the `EPackage`.


### EClass

An `EClass` has many useful features:

| feature                  | description | type
| ---                      | ---         | ---
| `name`                   | The unqualified name, e.g. 'Car'                   | `String`
| `qualifiedName`          | The qualified name, e.g. 'MyModel::Car'            | `String`
| `eAttributes`            | All attributes defined in this class.        |`Enumeration<ECore::EAttribute>`
| `eReferences`            | All references (containment and regular) defined in this class | `Enumeration<ECore::EReference>`
| `eAllAttributes`         | `eAttributes` from this and all super classes | `Enumeration<ECore::EAttribute>`
| `eAllContainments`       | `eReferences` from this and all super classes that are containments | `Enumeration<ECore::EReference>`
| `eAllReferences`         | `eReferences` from this and all super classes  | `Enumeration<ECore::EReference>`
| `eAllStructuralFeatures` | all `eAttributes` and `eReferences` from this and all super classes | `Enumeration<ECore::EStructuralFeature>`
| `eAllSubTypes`           | all sub types of the `EClass` | `Enumeration<ECore::EClass>` 
| `eAllSuperTypes`         | all super types of the EClass | `Enumeration<ECore::EClass>` 

And again, since this is in an `ECore` model, it is possible to manipulate the model, we can add / remove structural features and get/set the attributes.

In essence, the `ECore` model API makes it possible to do the same kind of meta programming that
can be done in Ruby; dynamically creating classes with attributes and references. The differences are that what we create with `ECore` is type safe, and that we also get the model (which we can serialize, and later deserialize to get exactly the same implementation, or we can send it to another system using another platform, and it can in turn dynamically generate the logic that is needed to operate on this model). This is what makes modeling a corner stone for polyglot programming.

### ENamedElement

Simply something that has a formal name.

### ETypedElement

An `ETypedElement` is an `ENamedElement`, and adds the following:

| feature     | description | type
| ---         | ---         | ---
| ordered     | (only for information stating that order is significant) | `Boolean`
| unique      | for multi valued attributes control if values are unique (references are always unique) | `Boolean`
| lowerBound  | the minimum number of occurances  | `Integer`
| upperBound  | the maximum number of ocurrances  | `Integer`
| many        | derived, if upperBound > 1        | `Integer`
| required    | derived, if lowerBound < 1        | `Integer`
| eType       | reference to the type             | `EClass` or `EDataType`

Concretely, we use these attributes when modeling an attribute:

    has_many_attr 'nick_names', String, :lowerBound => 0, :upperBound => -1, :unique => true
    
This means no nick name, or as many as you like, and they are unique.

### EStrucuralFeature

An `EStrucuralFeature` is an `ETypedElement`, and it is the base class for `EAttribute` and `EReference`, and it has attributes and operations that are common to both.

The attributes of interest are:

| attribute             | description | type
| ---                   | ---         | ---
| changeable            | can the value be externally set | `Boolean`
| volatile              | does the attribute have storage in the object (typically false for computed/derived values) | `Boolean`
| transient             | transient objects are omitted from serialization | `Boolean`
| defaultValueLiteral   | the default value in String form | `String`
| defaultValue          | the default value as instance of the attribute's data type | `Object`
| unsettable            | can the attribute be unset (see previous post) | `Boolean`
| derived               | is the attribute computed (requires implementing a method if true) | `Boolean`

Again, by looking at the ECore model, you can find additional methods.

Concretely, we use these when defining attributes (typically only for attributes, but we may
defined derived references that represent filtered sets of other references, we may define transient
containments etc.)

    has_attr 'reg_nbr', String, :defaultValueLiteral => "UNREGISTERED"
    
I will come back to how to define derived/computed features in a future post.

### EAttribute

An `EAttribute` only adds a reference to `EDataType` (the type of the attribute), and the ability to denotes that it is a primary key/identity attribute 
(which can be useful if we are transforming the model and need to be able to determine a primary key for a class, but it is not generally needed).

### EReference

As you have seen in earlier posts, references are either containment references (the diamond shaped relationships in the diagrams), or regular references (no diamond in the diagram). This is expressed with a `Boolean` attribute `containment` on the *containing side*, and `container` on the *contained side* (if the containment reference is bi-directional). When a reference is bi-directional, this is represented by two instances that know about each other via the `eOpposite` attribute.

If you study the model you will find that it is also possible to define that the relationship is based on a set of key attributes. (This is rarely used, but of value for models that should be
easily transformed to database schemas).

Gratefully we do not have to deal with all these details when defining references using
the RGen Metamodel Builder. You have already seen in the previous posts how easy it is
to create references - filling in the `containment`/`container`, and `eOpposite` is done for us, but
know you know about the structure that is actually build inside the Ecore model.

### EMF tutorial, Fun with Graphic Modeling in Eclipse

If you are interested in playing with Ecore models and want to use a graphical tool to do so, you can checkout [this tutorial by Vogella][10]. (If you want to do this, it is best to start with an Eclipse IDE and not install it into your Geppetto (the Puppet IDE), as it will bloat your Geppetto with a complete Java development environment).

I almost always use the graphical tools at the start of a project to organize my ideas even if
I later do not use modeling technology in the implementation. I find that it forces me to have good
definitions of what things are. If I can not express it in a model, or the model turns out to be horribly ugly, then I probably do not understand the domain well enough (or the domain is horribly messy to begin with...)

### Further Reading

If you are interested in more in-depth information about Ecore, you can checkout [this EMF book][12], although being Java and Eclipse centric the Ecore part itself is generic.

### Closing Remarks

I am sorry about all the theory and documentation flavor of this post. I wanted to give you enough details about what happens under the hood while not dragging it out for too long. As you probably have understood, you really do not need to think about all these things when just defining and using models as an implementation tool, but it is valuable to know that it is there and what it can do
for you should you have the need for polyglot programming, code generation, generation of data base or data schemas, transformations of data, etc.

In posts to follow I will show how to add operations to the modeled classes for things
like being able to store modeled objects in hashes, how to define derived attributes etc.

(Ok, you can breathe normally again).

[2]:https://gist.github.com/hlindberg/7fae2744d9a7266139fd
[10]:http://www.vogella.com/tutorials/EclipseEMF/article.html
[11]:http://ed-merks.blogspot.se/
[12]:http://www.informit.com/store/emf-eclipse-modeling-framework-9780321331885