# Changelog for AdiumBook

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

[Unreleased]:    https://github.com/aureliojargas/adiumbook/compare/v1.5.1...HEAD
[Version 1.5.1]: https://github.com/aureliojargas/adiumbook/releases/tag/v1.5.1
[Version 1.5]:   https://github.com/aureliojargas/adiumbook/releases/tag/v1.5
[Version 1.4]:   https://github.com/aureliojargas/adiumbook/releases/tag/v1.4
[Version 1.3.1]: https://github.com/aureliojargas/adiumbook/releases/tag/v1.3.1
[Version 1.3]:   https://github.com/aureliojargas/adiumbook/releases/tag/v1.3
[Version 1.2]:   https://github.com/aureliojargas/adiumbook/releases/tag/v1.2
[Version 1.1]:   https://github.com/aureliojargas/adiumbook/releases/tag/v1.1
[Version 1.0]:   https://github.com/aureliojargas/adiumbook/releases/tag/v1.0

[issue #1]:  https://code.google.com/archive/p/adiumbook/issues/1
[issue #5]:  https://code.google.com/archive/p/adiumbook/issues/5
[issue #10]: https://code.google.com/archive/p/adiumbook/issues/10
[issue #12]: https://code.google.com/archive/p/adiumbook/issues/12
[issue #14]: https://code.google.com/archive/p/adiumbook/issues/14
[issue #19]: https://code.google.com/archive/p/adiumbook/issues/19
[issue #33]: https://code.google.com/archive/p/adiumbook/issues/33
[issue #35]: https://code.google.com/archive/p/adiumbook/issues/35


## [Version 1.5.1] released in November 2009

This is a bugfix release to make AdiumBook 1.5 work on the new Snow Leopard. Users still in Leopard have no need to upgrade.

 * Fixed the Set IM button that wasn't saving changes in Snow Leopard (closes [issue #33])
 * Fixed the "Address Book contacts with no IM" report under Snow Leopard (closes [issue #35])
 * Fixed the following reports under Snow Leopard:
   * Address Book contacts with AIM/.Mac
   * Address Book contacts with ICQ
   * Address Book contacts with MSN
   * Address Book contacts with Yahoo!
   * Address Book contacts with Jabber

## [Version 1.5] released in March 2009

 * Fixed compatibility issues, now works with Adium 1.3 and newer.
 * Fixed the display of Adium pictures, which wasn't working for some contacts. (closes [issue #19])
 * New reports:
   * Adium contacts with AIM/Mac
   * Adium contacts with ICQ
   * Adium contacts with MSN
   * Adium contacts with Yahoo!
   * Adium contacts with Jabber/GTalk
   * Adium contacts with other IM
   * Adium contacts with picture
   * Adium contacts without picture
   * Address Book contacts with picture
 * Added automatic software update, provided by [Sparkle](http://sparkle.andymatuschak.org/). (closes [issue #14])
 * We're back to the standard About panel, featuring:
   * the release version number (1.5)
   * the SVN revision number (50)
   * a link to the AdiumBook sources
   * pretty credits with donators names
 * Service icons (ICQ, AIM, MSN, etc) were updated to match the new Adium icons.
 * New menu item AdiumBook > [i use this](http://osx.iusethis.com/app/adiumbook).
 * Improved Help contents.
 * AdiumBook is now packaged as a ZIP file instead DMG, to keep things simple.

This release took me *29 work hours* to be made.
I hope you like it!

## [Version 1.4] released in July 2008

 * The main window is now resizable, helping users with hundreds of contacts. (closes [issue #1])
 * Added full text search for the "Find in Adium" and "Find in AB" buttons, now scanning the Adium's names and screen names and Address Book's names, nicknames, e-mails, AIM/ICQ/MSN/Yahoo/Jabber names. (closes [issue #12])
 * Improved "AB contacts not in Adium" report, now finding AIM contacts with spaces on the screen name. ([issue #10])
 * Added a progress bar for the "Adium contacts not in AB" and "AB contacts not in Adium" reports, because they take some time to terminate.
 * New menu item AdiumBook > Report an issue.
 * Clicking news:
   * Clicking the contact picture now reveals its file in Finder.
   * Clicking the Address Book icon brings the Address Book application to the front.
   * Clicking the sleepy Adium icon checks if Adium is online.
   * Clicking the awake Adium icon makes a... discover for yourself! :)
 * The contact details are now cleared when scrolling results with the keyboard, avoiding visual confusion.
 * Added tool tips to the multiple IMs popup buttons (Address Book pane), informing about the right click feature.
 * Improved tool tips for the Set buttons, making clear that de "Set IM" is an append operation (non destructive) and the "Set Pic" is an overwrite operation (destructive).
 * Improved About window, now listing the AdiumBook supporters.
 * Improved Help contents.

 * *Note:* Besides the new full text search on the Find buttons, the reports still search only by service. This is desired, because you still need to fill the correct IM field in Address Book for those contacts.

 * *Note for Tiger users:* This release just works in Leopard. The Adium bug on AppleScript for Tiger was not fixed (see [issue #5]), we'll have to wait until the future Adium 1.3 release. For now, you must use AdiumBook 1.3 and Adium 1.1.4 or older.

This release took me *32 work hours* to be made.
I hope you like it!

## [Version 1.3.1] released in January 2008

 * Code updated to support the new Adium version 1.2 (Leopard only by now)
 * Program name changed from Adium Book to AdiumBook.
 * License changed from "pick your favorite" to BSD.

 * Note 1: Adium version 1.2 came with a brand new AppleScript support. Although more powerful and flexible, it broke compatibility with previous Adium versions. This demanded huge changes in AdiumBook, a lot of code was rewritten using the new syntax. Starting from this release, *AdiumBook will only work with Adium 1.2 or newer.* You can continue using the previous AdiumBook 1.3 if your Adium is 1.1.4 or older.

 * Note 2: There seem to have some issues with the new Adium AppleScript support in Tiger (see [issue #5]), so *this release just works in Leopard*. If you're in Tiger you must use AdiumBook 1.3 and Adium 1.1.4 or older. I hope this limitation will be fixed in future versions.

This release took me *16 work hours* to be made.
I hope you like it!

## [Version 1.3] released in September 2006

 * Reworked interface
   * Cleaner, simpler
   * Buttons with labels
 * Performance tweaks - Now it's even faster!
   * Changed some line order increasing visual flow
   * clear_details using "delete contents of every" instead doing 1 by 1
   * Commented all the myLog() calls
 * Support for multiple accounts in Address Book view - Finally!
 * New menu item Report > Your statistics
 * New menu item Adium Book > Sponsor new features
 * The Set IM button now creates a new field instead overwriting existent data _(thanks raeburn)_
 * Fixed Jabber accounts issues with Reports _(thanks raeburn)_
   * Report > AB contacts with no IM: not listing Jabber-only accounts anymore
   * Report > AB contacts not in Adium: not listing Jabber-only accounts anymore
 * Universal binary
 * Now showing nickname even when the name is long
 * Right click on popup button selects the text
 * Magic word
 * Removed minor version: 1.3 (1.3)
 * Now using User Defaults system
   * Action counters for search, report, set, add
   * Read defaults at awake, save_defaults() at stop points
 * Make sure Address Book is saved after adding a card

## [Version 1.2] released in August 2006

 * Added Google Talk support (mapped to Jabber on Address Book) _(thanks john mora)_
 * New button to reveal the contact's card on Address Book
 * New Help menu with... Help! :)
 * New Donate menu item, so you can contribute with the project
 * Fixed some "try" blocks that were causing warnings on Address Book logs

## [Version 1.1] released in September 2005

 * Added Jabber support (search, show, set and report) _(thanks gwm)_
 * New button to set the IM field in Address Book _(thanks kojima)_
 * New button to add a new card to Address Book _(thanks gwm, token)_
 * Now the first contact found on searches is autoselected _(thanks gwm)_
 * Now pressing Enter/Return/Space on search results selects the contact
 * Now all the contacts are loaded on startup (and in empty searches) _(thanks fabio)_
 * Now the application quits when the window is closed _(thanks gwm)_
 * Fixed issues with new Adium version (0.84) _(thanks gwm)_
 * General fixes on interface and menus to make the application more compliant with Apple Human Interface Guidelines
 * Interface revamped:
   * No more brushed metal
   * No more small/mini controls (tiny texts and components)
   * Push buttons replaced by pretty square buttons with icons
   * Now the IM icons becomes disabled if the field is empty (no more N/A)

## [Version 1.0] released in August 2005

 * Text search
 * Cross search ("Find in" buttons)
 * Reports menu (8 reports)
 * Copy Adium picture to Address Book ("Set Picture" button)
 * Adium Online/Offline status detection
 * Go to Website menu item
