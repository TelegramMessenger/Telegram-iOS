# Layout Debugger

## Motivation

The layout system is arguably one of the hardest parts to deal with in the framework.  There are many factors, such as constrained size range, preferred size and flex properties, that make a layout spec to behave in a certain way.  As a result, it's often hard to debug a layout, as well as to help debugging because we have to grab the whole context of the layout in order to pinpoint the problem at hand.  Currently we have a couple of tools to help address this issue, namely ASCII art string and the layout inspector project from @hannahmbanana.

While the layout inspector project is definitely a step toward the right direction and was proven to be helpful, I think we can do a lot more.  One drawback of that project is that we didn't have a clear integration contract with the core components of the framework.  We ended up introducing lots of complexities to ASDisplayNode that were hard to reason and mantain.  Another problem is it was difficult to bootstrap the tool into existing code/layout.

This project aims to provide a functional layout debugging solution that requires minimal change to the core framework, is easy to setup and works out-of-the-box on existing applications.  These will be achieved by building an extension framework that is hosted in a separate repository, integrates with Texture core and leverages Chrome DevTools.

## Execution plan

At first, we'll build on top of [PonyDebugger](https://github.com/square/PonyDebugger).  I played with it for a few hours and [the result](https://www.dropbox.com/s/8bcpdgogoewmox9/view%20debugger.mov?dl=0) looks promising.  The bottom line is that we'll implement a new `PDDomainController` that is inspired by `PDDOMDomainController` but is catered toward `ASLayoutElement`.  The controller should expose style properties, allow editting those properties and, as a result, support hot reloading.  It should also expose the constrained size passed to each element during the previous layout pass.

Eventually, we'll possibly move away from PonyDebugger and implement our own framework due to a few reasons:

1. PonyDebugger is not actively maintained.  That might be because it's considered a "done" project, although the amount of open issues may suggest otherwise.
2. It's not easy to setup the environment, especially because of the [ponyd gateway server](https://github.com/square/PonyDebugger/tree/master/ponyd).  Ponyd is essentially a middleman that sits between the client code and Chrome DevTools.  It is implemented in Python and hosts its own version of DevTools.  Its bootstrap script is more or less broken.  It's not trivial (at least for me) to setup a working environment.  Instead, my limitted research showed that we can do better by letting the client app be a mDNS broadcaster and allowing Chrome DevTools to connect to it.  The workflow will be very straight-forward for developers, similar to [Stetho](https://facebook.github.io/stetho/)'s.  In addition, the whole project will be simpler because we don't need to maintain ponyd.
3. It contains other features besides layout debugging, such as network monitoring and remote logging.  While they are absolutely useful, they are not in the scope of this project and add complexities to it.

## Integration with Texture (core)

As mentioned above, this framework will be a seperate project that integrates with Texture.  Most of the changes in Texture's components, like `ASLayoutElement`, `ASDisplayNode` and `ASLayoutSpec`s, will be implemented as extensions inside the debugger framework.  We'll try as much as we can to minimalize changes in Texture (core) that are needed to support this project.

## Technical issues related to Texture (core)

There are a few technical difficulties that we need to address:

- Layout spec flattening:  Currently `ASDisplayNode` flattens its layout tree right after it receives an `ASLayout`.  As a result, `ASLayoutSpec` objects are discarded and are not available for inspecting/debugging.  My current solution is introducing a new `shouldSkipFlattening` flag that tells `ASDisplayNode` to keep its layout tree as is.  This flag defaults to `NO`.  In addition, we need to update `-layoutSublayouts` to skip any non-node objects in the tree.  We should avoid introducing runtime overheads to production code and projects that don't use the debugger.
- Style properties overrding:  It's common for client code to set flex properties to subnodes inside `-layoutSpecThatFits:`.  Doing this will override any values set to these properties by the debugger right before a layout pass which is needed for these changes to be taken into account.  My current idea is adding a special `style` object that is loaded once from the exising object and can be changed by the debugger.  This special object will be preferred over the built-in one when it's time to calculate a new layout.
- Manual layout is not supported:  Layouts that are done manually (via `-calculateSizeThatFits:` and `-layout`) can't be updated by the debugger.  Nodes inside these layouts are still available for inspecting though.

## Long-term ideas

Once we have a functional debugger with a solid foundation, we can start exploring below ideas:

- Remote debugging:  Since the client app is a mDNS broadcaster, I *think* it's possible to support remote debugging as well as pair programming: "I have a layout issue" "Let me connect to your runtime and inspect it".  Crazy I know!  Inspired by this [Chrome extension](https://github.com/auchenberg/devtools-remote).
- Layout spec injecting:  We may try to abstract `-layoutSpecThatFits:` in such a way that the entire layout specification of a node is not only defined within the class but can be loaded (or manipulated) elsewhere, be it from the debugger or even a backend server.

## Naming

I'm planning to call this project "Texture Debugger".  It'll be a suite of debugging tools tailored mainly for Texture framework.

