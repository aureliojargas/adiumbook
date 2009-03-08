-- Adium Book.applescript
-- AdiumBook

--  Created by Aurelio Marinho Jargas on Sun Jul 10 2005.
--  License: BSD
--  More info: http://aurelio.net/soft

(* 
						Code Overview

The interface is divided in two parts (views): Adium at left and Address Book
at right. The two properties adiumView and abView are shortcuts to refer to
each side. The name of the components are the same on both boxes, so
generic functions can change info on any side, you just have to tell which
view you want.

Before any search, first all the box's info is cleared. The clear_* functions are
used. The search procedure is always the same: clear, start the wheel,
search, populate results table, select the first contact, stop the wheel.

There are three types of search:
- By text: uses the search field and search_*_by_text functions
- Cross search: uses the Find buttons and search_*_by_{id, service} functions
- Reports: uses the Reports menu and search_report_* functions

Action events are triggered by:
- Filling search field and hitting Return (to make a text search)
- Clicking on a person on the results table (to get his/her details)
- Clicking on a table heading (to reverse the column sort ordering)
- Clicking buttons
- Choosing an item on Reports menu (to make a report search)

Some interesting parts to study are:
- populate_table function
- set_person_details_on_screen function
- "awake from nib" event handler


						XXX - Some gotchas

Changing IM info on AB

	If you change or add new IM numbers in Address Book for a contact
	already in Adium, Adium adds new "virtual" contacts for any change,
	and they will appear on the search results (old and new values).
	This is an Adium bug. You must quit Adium to reset the false positives.
	Seen on Adium 0.82.

Adium must be Online

	Adium *must* be online for the searches and reports to work 100%.
	If Adium is offline it only finds very few contacts with poor details
	(like no ICQ names)

Image gotchas
	
	The "load image" command of "image view" requires a POSIX file path
	(it needs a disk file), but both Address Book and Adium only returns the
	TIFF data of the images, with no path reference.
	
	To set the person picture on the screen, we have two workarounds:
	
		1) Guess the image file path from the person ID
			
			It is fast, clean and the one used now.
			
			We know the default pictures folder on disk,
			we know that the filename uses the person ID,
			so we can guess the complete path for the picture.
			
			Issues:
				It doesn't work for the Address Book owner.
				His/her picture is located outside AB folder.
						
				Some pictures on Adium folder have strange
				names like MetaContact-13 and TEMP-*.tiff.
				I don't know about them.
			
				Older or newer Adium/AB versions may use
				a different path for pictures. We can't blindly
				rely on that.
		
		2) Dump the TIFF data to a temporary file
		
			I refuse to do it :)
			
			Update: Since AdiumBook 1.5, the Adium picture is
			saved to a temporary file :( Adium has changed the
			picture filename to something encoded, such as
			838b3f3242aba1a46b3bb188757ee8b2ec68de3a.jpg
			As we can't guess the filename anymore, the tempfile
			is required.
			

Adium versions
	
	< 0.84:
		- Service IDs: AIM, Mac, ICQ, MSN, Yahoo, Jabber
		- set adiumStatus to my status of the first Adium controller
		

	>= 0.84:
		- Service IDs: AIM, Mac, ICQ, MSN, Yahoo!, Jabber
		- set adiumStatus to my status type of the first Adium controller

	>= 1.2:
		- The AppleScript support was completely rewritten, breaking everything

Tips
	Monitor execution with Console.app to track for AB and Adium warnings
	Comment log calls: ^(\t+)((my )*mylog\(.*, [1-5]\))      \1--\2
	set personID to contents of data cell "id" of selected data row of table view 1 of scroll view 1 of theView
	set personLogin to contents of data cell "nick" of selected data row of table view 1 of scroll view 1 of theView
*)

-- The only properties that you may want to change
property theLogLevel : 3 -- Zero: no log, 1: informative log, 2: detailed log, 3: ugly log
property abImDefaultLabel : "home" -- Used by the "Set IM" button (home, work, other)


-- These are set on "awake from nib"
property adiumView : ""
property abView : ""
property abPicturesFolder : ""
property adiumContactPicturePath : ""
property adiumContacts : {0, 0} -- Found / Total
property abContacts : {0, 0}
property adiumOnline : true -- Changing here changes nothing
property adiumFlapping : false -- Changing here changes nothing
property adiumServiceId : {aim:"AIM", mac:"Mac", icq:"ICQ", msn:"MSN", yim:"Yahoo!", jab:"Jabber", gtalk:"GTalk"}

-- The statistics
property donateReminderInterval : 25
property counterSearch : 0
property counterReport : 0
property counterSet : 0
property counterAdd : 0
property lastReminder : 0
property magicWord : "" -- Mistery!
property quack : ""

-- Some random text
property requiredAdiumVersion : "1.2"
property myUrl : "http://aurelio.net/soft/adiumbook/"
property adiumUrl : "http://www.adiumx.com"
property issueUrl : "http://code.google.com/p/adiumbook/issues/list"
property iusethisUrl : "http://osx.iusethis.com/app/adiumbook"
property donateUrl : "https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=verde%40aurelio%2enet&item_name=AdiumBook&no_shipping=1&return=http%3a%2f%2faurelio%2enet%2fdonate%2dthanks%2ehtml&cn=Please%20leave%20a%20comment%20to%20me&tax=0&currency_code=USD&bn=PP%2dDonationsBF&charset=UTF%2d8"

property tooltipAdiumOffline : "Adium is Offline. Please login or you'll have poor search results."
property tooltipAdiumOnline : "Quack!"
property tooltipFindInAb : "Find this contact in Address Book"
property tooltipFindInAdium : "Find this contact in Adium"
property tooltipRevealInAb : "Reveal this contact's card in Address Book"
property tooltipAddToAb : "Create a NEW CARD for this contact in Address Book"
property tooltipSetAbIm : "Set the IM field in Address Book (will append, preserving any existing contents)"
property tooltipSetAbPicture : "Set the PICTURE in Address Book (will override any existing picture)"
property tooltipCopyImClipboard : "Right click here to copy this IM to the clipboard"

property msgWrongAdiumVersion : "Unsupported Adium version."
property msgWrongAdiumVersionDetails : "Your current version of Adium is unsupported. Please upgrade to the most recent version of Adium, or use the older AdiumBook version 1.3."
property msgSelectPersonToSetAbInfo : "No contact selected in Address Book."
property msgSelectPersonToSetAbInfoDetails : "To set somebody's IM or picture, first you need to select the contact on the Address Book view."
property msgPersonAlreadyInAb : "This contact is already added."
property msgPersonAlreadyInAbDetails : "This contact already has a card on your Address Book. Press the Find button to see it."

----------------------------------------------------------------------------------

on myLog(theMessage, theLevel)
	if theLevel is not greater than theLogLevel then log (theMessage)
end myLog

on write_file(filePath, fileContents)
	set f to filePath as POSIX file
	set f to open for access f with write permission
	set eof of f to 0
	write fileContents to f
	close access f
end write_file

on get_adium_service(accountID)
	tell application "Adium" to return (name of service of (first account whose id is accountID))
end get_adium_service

on populate_popup(thePopup, theList)
	repeat with i from 1 to count of theList
		make new menu item at the end of menu items of menu of thePopup with properties {title:item i of theList, enabled:true}
	end repeat
	set tool tip of thePopup to tooltipCopyImClipboard
end populate_popup

on seconds_to_string(s)
	-- Copied from http://hacks.oreilly.com/pub/h/4802
	set txt to ""
	set d to s div 86400 -- number of seconds in a day
	set s to s mod 86400 -- save the remainder
	if d = 1 then set txt to " 1 day"
	if d > 1 then set txt to " " & d & " days"
	
	set h to s div 3600 -- seconds in an hour
	set s to s mod 3600 -- save the remainder
	if h = 1 then set txt to txt & " 1 hour"
	if h > 1 then set txt to txt & " " & h & " hours"
	
	set m to s div 60 -- left over minutes
	if m = 1 then set txt to txt & " 1 minute"
	if m > 1 then set txt to txt & " " & m & " minutes"
	
	if txt = "" then set txt to " less than a minute" -- occurs because we dropped the seconds remainder
	return items 2 thru -1 of txt as text -- del leading space
end seconds_to_string

-- Sample: ICQ.1234567
on compose_adium_search_patterns(theData)
	set searchPatterns to {}
	repeat with thisLogin in icq of theData
		set the end of searchPatterns to {icq of adiumServiceId, thisLogin}
	end repeat
	repeat with thisLogin in msn of theData
		set the end of searchPatterns to {msn of adiumServiceId, thisLogin}
	end repeat
	repeat with thisLogin in yim of theData
		set the end of searchPatterns to {yim of adiumServiceId, thisLogin}
	end repeat
	repeat with thisLogin in jab of theData
		set the end of searchPatterns to {jab of adiumServiceId, thisLogin}
		set the end of searchPatterns to {gtalk of adiumServiceId, thisLogin}
	end repeat
	repeat with thisLogin in aim of theData
		set the end of searchPatterns to {aim of adiumServiceId, thisLogin}
		set the end of searchPatterns to {aim of adiumServiceId, (words in thisLogin) as text} -- no spaces (AIM ignores them)
		set the end of searchPatterns to {mac of adiumServiceId, thisLogin}
	end repeat
	--myLog(searchPatterns, 3)
	return searchPatterns
end compose_adium_search_patterns

on save_defaults()
	--myLog("action: save defaults", 2)
	
	tell user defaults -- save current state
		set contents of default entry "counterSearch" to counterSearch
		set contents of default entry "counterReport" to counterReport
		set contents of default entry "counterSet" to counterSet
		set contents of default entry "counterAdd" to counterAdd
	end tell
	call method "synchronize" of object user defaults -- Save in disk
end save_defaults

on set_adium_status()
	--myLog("action: set adium on/offline status", 2)
	
	set currentStatus to adiumOnline
	
	-- Each account has its own status: {invisible, invisible, available, offline, offline}
	-- You're online if any status isn't "offline"
	tell application "Adium"
		set allStatus to status type of every account
		set adiumOnline to available is in allStatus or away is in allStatus or invisible is in allStatus
	end tell
	
	if adiumOnline is not currentStatus then
		if not adiumOnline then
			set image of button "adium_icon" of adiumView to load image "adium-offline"
			set tool tip of button "adium_icon" of adiumView to tooltipAdiumOffline
		else
			-- When Adium became online, flap once and quack
			set image of button "adium_icon" of adiumView to load image "adium-flap"
			play quack
			delay 1
			set image of button "adium_icon" of adiumView to load image "adium-online"
			set adiumFlapping to false
			set tool tip of button "adium_icon" of adiumView to tooltipAdiumOnline
		end if
	end if
end set_adium_status

on set_status_bar(theView, theMessage)
	set content of text field "status bar" of theView to theMessage
end set_status_bar

on set_box_totals(theView, currentCount)
	if name of theView as text is "adium" then
		tell application "Adium" to set theTotal to count (every contact)
		set adiumContacts to {currentCount, theTotal}
	else
		tell application "Address Book" to set theTotal to count (id of every person)
		set abContacts to {currentCount, theTotal}
	end if
end set_box_totals

on get_box_totals(theView)
	if name of theView as text is "adium" then return adiumContacts
	return abContacts
end get_box_totals

on format_totals(theCount)
	return (item 1 of theCount as text) & " of " & (item 2 of theCount as text) & " contacts"
end format_totals

on add_x(x)
	repeat with i in {120, 121, 122, 122, 121}
		set x to x & (ASCII character i)
	end repeat
end add_x

on get_stats_report()
	(*
Saved time (in seconds) for all tasks:

Search AB by text: 0
Search Adium by text: exponential (no Find function, depends contact list size)

Search Adium contact in AB: 20s
	Get Info (cmd-i) > Settings tab > Select login > Copy > Switch to AB > Click search field > Paste > Enter
	or
	Type FULL user login on AB search field

Search AB contact in Adium: 30s or exponential
	show no group bubbles, order alphabetically, visual search by name
	or
	search for ALL services - 5

Reports: 9min 
1) AIM:  (search for @mac.com or make applescript)
2) ICQ:  (make applescript)
3) MSN:  (search for hotmail or make applescript)
4) YIM:  (make applescript)
5) JAB:  (make applescript)
	(15s to open Script Editor, 30s to type applescript in one shot)
6) !IM:  (make applescript, 120 to type)
7) !PIC: (make applescript, 5+min)
8) Adium not AB: exponential
9) AB not Adium: exponential

Set IM: 20
	Get Info (cmd-i) > Settings tab > Select login > Copy > Switch to AB > Edit > Click IM field > Paste

Set picture: 20
	Edit (on AB) > Switch to Adium > Get Info (cmd-i) > Settings tab > Drag picture > Switch to AB > Drop on picture box

Add: 60
	(+) on AB, type full name, Set picture procedure (15), alternation to copy/paste IMs (7 * 5)
*)
	set theStats to tab & counterSearch & " searches" & return & tab & counterReport & " reports" & return & tab & counterSet & " card updates" & return & tab & counterAdd & " cards added"
	
	set savedSeconds to counterSearch * 55 + counterReport * 60 * 9 + counterSet * 20 + counterAdd * 85
	set theReport to "This is what you have made so far:" & return & theStats & return & return & "AdiumBook has saved you from " & seconds_to_string(savedSeconds) & " of tedious work."
	return theReport
end get_stats_report

----------------[ clear ]-------------------

on disable_button(theName, theView)
	tell box "details" of theView
		set enabled of button theName to false
		delete tool tip of button theName
	end tell
end disable_button

on clear_search(theView)
	clear_table(theView)
	set content of text field "search" of theView to ""
	set_status_bar(theView, "")
end clear_search

on clear_details(theView)
	--myLog("action: clear details", 2)
	
	set viewName to (name of theView as text)
	tell box "details" of theView
		
		-- Order matters! Avoid funky random disappearing, make it like a top-down wave
		delete image of image view "picture"
		delete contents of (every text field whose name is not "toolbar")
		if viewName is "ab" then set visible of every popup button to false
		set enabled of every button to false -- also affects popup buttons :/
		
		-- Unnoticeable for the user, so comes last
		delete tool tip of image view "picture"
		delete tool tip of every button
		if viewName is "ab" then
			delete every menu item of menu of every popup button
			set enabled of every popup button to true -- restore
		end if
	end tell
end clear_details

on clear_table(theView)
	--myLog("action: clear table", 2)
	
	if name of theView as text is "adium" then
		set item 1 of adiumContacts to 0
	else
		set item 1 of abContacts to 0
	end if
	set statusMessage to format_totals(get_box_totals(theView))
	tell theView
		delete data rows of data source of table view 1 of scroll view 1
		set content of text field "contacts found" to statusMessage
	end tell
end clear_table

-----------------------------------------------------

on populate_table(theView, theNewData)
	--myLog("action: populate table", 2)
	
	set_box_totals(theView, count of theNewData)
	set statusMessage to format_totals(get_box_totals(theView))
	
	tell theView
		if name as text is "ab" then
			-- remove <null>'s from empty AB fields
			repeat with thisPerson in theNewData
				if nick of thisPerson is missing value then set nick of thisPerson to ""
				if |name| of thisPerson is missing value then set |name| of thisPerson to ""
			end repeat
		end if
		set table to data source of table view 1 of scroll view 1
		set update views of table to false
		append table with theNewData
		set update views of table to true
		set content of text field "contacts found" to statusMessage
	end tell
end populate_table


----------------[ search ]-------------------

on search_adium(theSearchText)
	start progress indicator "progress" of adiumView
	clear_details(adiumView)
	clear_table(adiumView)
	set_status_bar(adiumView, "Searching...")
	populate_table(adiumView, search_adium_by_text(theSearchText))
	auto_show_first_result(adiumView)
	set_status_bar(adiumView, "Search results")
	stop progress indicator "progress" of adiumView
end search_adium

on search_ab(theSearchText)
	start progress indicator "progress" of abView
	clear_details(abView)
	clear_table(abView)
	set_status_bar(abView, "Searching...")
	populate_table(abView, search_ab_name_nick(theSearchText))
	auto_show_first_result(abView)
	set_status_bar(abView, "Search results")
	stop progress indicator "progress" of abView
end search_ab

on search_adium_by_service_test(theData)
	set found to 0
	set {serviceName, contactLogin} to theData
	tell application "Adium" to set found to count of (every contact of (every account of service serviceName) whose name is contactLogin)
	return found is greater than 0
end search_adium_by_service_test

on search_ab_by_service_test(theService, theLogin)
	set found to 0
	tell application "Address Book"
		-- There is any contact using this IM id?
		if theService is in {aim, mac} of adiumServiceId then
			ignoring white space -- XXX not working, needed for AIM
				set found to count (every person whose (value of AIM handles) contains theLogin)
			end ignoring
		else if theService is (icq of adiumServiceId) then
			set found to count (every person whose (value of ICQ handles) contains theLogin)
		else if theService is (msn of adiumServiceId) then
			set found to count (every person whose (value of MSN handles) contains theLogin)
		else if theService is (yim of adiumServiceId) then
			set found to count of (every person whose (value of Yahoo handles) contains theLogin)
		else if theService is in {jab, gtalk} of adiumServiceId then
			set found to count of (every person whose (value of Jabber handles) contains theLogin)
		end if
	end tell
	return found is greater than 0
end search_ab_by_service_test

on search_ab_text(theLogin)
	set theResults to {}
	tell application "Address Book"
		ignoring white space -- XXX not working, needed for AIM
			set theResults to {id, nickname, name} of (every person whose Â
				((value of AIM handles) contains theLogin or Â
					(value of ICQ handles) contains theLogin or Â
					(value of MSN handles) contains theLogin or Â
					(value of Yahoo handles) contains theLogin or Â
					(value of Jabber handles) contains theLogin or Â
					(value of emails) contains theLogin or Â
					name contains theLogin or Â
					nickname contains theLogin))
		end ignoring
	end tell
	return convert_results_to_datasource_record(theResults)
end search_ab_text


-- Routines to find people who match the given text pattern
-- They return a record ready to be used on the data sources

-- Nice trick to speed up searches, convert a list of lists into a list of records
on convert_results_to_datasource_record(theResults)
	set theRecords to {}
	set {theID, theNick, theName} to theResults
	repeat with i from 1 to (count of theID)
		set the end of theRecords to {|id|:item i of theID, nick:item i of theNick, |name|:item i of theName}
	end repeat
	return theRecords
end convert_results_to_datasource_record

on remove_dups_from_datasource_record(theRecords)
	set uniqueRecords to {}
	set uniqueIDs to {}
	repeat with i from 1 to count of theRecords
		if (|id| of item i of theRecords) is not in uniqueIDs then
			set the end of uniqueRecords to item i of theRecords
			set the end of uniqueIDs to |id| of item i of theRecords
		end if
	end repeat
	return uniqueRecords
end remove_dups_from_datasource_record

on remove_dups_from_list(theList)
	set ret to {}
	repeat with i from 1 to count of theList
		if item i of theList is not in ret then set end of ret to item i of theList
	end repeat
	return ret
end remove_dups_from_list

on remove_empty_items(theList)
	set ret to {}
	repeat with i from 1 to count theList
		if theList's item i is not in {missing value, ""} then set end of ret to theList's item i as text
	end repeat
	return ret
end remove_empty_items

on search_adium_by_text(theSearchText)
	tell application "Adium"
		if theSearchText is not "" then
			ignoring white space -- XXX not working, needed for AIM
				set theResults to {id of account, name, display name} of (every contact whose (name contains theSearchText) or (display name contains theSearchText))
			end ignoring
		else
			set theResults to {id of account, name, display name} of every contact
		end if
	end tell
	return convert_results_to_datasource_record(theResults)
end search_adium_by_text



on search_ab_name_nick(theSearchText)
	tell application "Address Book"
		if theSearchText is not "" then
			set theResults to {id, nickname, name} of (every person whose (nickname contains theSearchText) or (name contains theSearchText))
		else
			set theResults to {id, nickname, name} of every person
		end if
	end tell
	return convert_results_to_datasource_record(theResults)
end search_ab_name_nick

on search_report_ab_no_im()
	tell application "Address Book"
		set theResults to {id, nickname, name} of (every person whose AIM handles is {} and ICQ handles is {} and MSN handles is {} and Yahoo handles is {} and Jabber handles is {})
		
	end tell
	return convert_results_to_datasource_record(theResults)
end search_report_ab_no_im

-- XXX that would be cool if "every person whose image is not missing value" works...
on search_report_ab_no_picture()
	(*
	-- Default way, seems good but crashes on Panther :/
	set thePeople to {}
	tell application "Address Book"
		repeat with i from 1 to (count people)
			tell item i of people
				--my myLog("searching for " & name, 2)
				if not (exists image) then
					--my myLog("no picture found", 3)
					set the end of thePeople to {|id|:id, nick:nickname, |name|:name}
				end if
			end tell
		end repeat
	end tell
	return thePeople
	*)
	
	-- Alternative way, don't crash. Sometimes faster sometimes don't (takes all images, argh!)
	tell application "Address Book"
		set theResults to {{}, {}, {}}
		set {theID, theNick, theName, theImage} to {id, nickname, name, image} of every person
		repeat with i from 1 to (count of theID)
			if item i of theImage is missing value then
				set the end of item 1 of theResults to item i of theID
				set the end of item 2 of theResults to item i of theNick
				set the end of item 3 of theResults to item i of theName
			end if
		end repeat
	end tell
	return convert_results_to_datasource_record(theResults)
end search_report_ab_no_picture

on search_report_ab_with_service(theService)
	tell application "Address Book"
		if theService is "aim" then
			set theResults to {id, nickname, name} of (every person whose AIM handles is not {})
		else if theService is "icq" then
			set theResults to {id, nickname, name} of (every person whose ICQ handles is not {})
		else if theService is "msn" then
			set theResults to {id, nickname, name} of (every person whose MSN handles is not {})
		else if theService is "yim" then
			set theResults to {id, nickname, name} of (every person whose Yahoo handles is not {})
		else if theService is "jab" then
			set theResults to {id, nickname, name} of (every person whose Jabber handles is not {})
		else
			set theResults to {"", "", ""}
			my myLog("** Unknown service: " & theService, 0)
		end if
	end tell
	return convert_results_to_datasource_record(theResults)
end search_report_ab_with_service


-- Results a data-source-ready list of Adium people not found in AB
on search_report_not_in_ab()
	set reportResults to {}
	
	-- Get all Adium contacts
	tell application "Adium"
		set {accountIds, serviceNames, contactLogins, displayNames} to {id of account, name of service of account, name, display name} of every contact
	end tell
	
	-- Search one by one in AB
	repeat with i from 1 to (count of serviceNames)
		--myLog("searching for " & (item i of contactLogins), 2)
		
		set content of progress indicator "progress_report" of adiumView to i
		if not search_ab_by_service_test(item i of serviceNames, item i of contactLogins) then
			--myLog("not found", 3)
			set the end of reportResults to {|id|:item i of accountIds, nick:item i of contactLogins, |name|:item i of displayNames}
		end if
	end repeat
	
	return reportResults
end search_report_not_in_ab


-- Handler for next search_report_not_in_adium because can't call progress inside "tell AB"...
on set_ab_progress(i)
	set content of progress indicator "progress_report" of abView to i
end set_ab_progress

-- Results a data-source-ready list of AB people not found in Adium
on search_report_not_in_adium()
	set reportResults to {}
	tell application "Address Book"
		set i to 0
		repeat with thisPerson in every person
			set i to i + 1
			my set_ab_progress(i)
			
			tell thisPerson
				-- Search only if AB contact has at least one IM login
				if AIM handles & ICQ handles & MSN handles & Yahoo handles & Jabber handles is not {} then
					--my myLog("searching for " & name, 2)
					
					-- Compose Adium-like search patterns
					set userInfo to {aim:"", icq:"", msn:"", yim:"", jab:""}
					if AIM handles is not {} then set aim of userInfo to (value of AIM handles)
					if ICQ handles is not {} then set icq of userInfo to (value of ICQ handles)
					if MSN handles is not {} then set msn of userInfo to (value of MSN handles)
					if Yahoo handles is not {} then set yim of userInfo to (value of Yahoo handles)
					if Jabber handles is not {} then set jab of userInfo to (value of Jabber handles)
					set searchPatterns to my compose_adium_search_patterns(userInfo)
					
					-- Search this person in Adium
					set found to false
					repeat with searchPattern in searchPatterns
						if my search_adium_by_service_test(searchPattern) then
							set found to true
							exit repeat
						end if
					end repeat
					
					-- Person not found, add to results
					if found is false then
						--my myLog("not found", 3)
						set thisPersonInfo to {|id|:id, nick:nickname, |name|:name}
						set the end of reportResults to thisPersonInfo
					end if
				end if
			end tell
		end repeat
	end tell
	return reportResults
end search_report_not_in_adium

-- Routines to extract the info from a specific person

on get_adium_person_details(accountID, contactLogin)
	
	set theInfo to {|name|:"", nick:"", |picture|:"", aim:"", icq:"", msn:"", yim:"", jab:""}
	set serviceName to get_adium_service(accountID)
	
	-- XXX "repeat/exit repeat" has proven to be best than "first contact of ..."
	tell application "Adium"
		repeat with thisContact in (every contact of (first account whose id is accountID) whose name is contactLogin)
			tell thisContact
				set |name| of theInfo to display name
				set |picture| of theInfo to adiumContactPicturePath
				try
					my write_file(adiumContactPicturePath, image)
				end try
				if serviceName is in {aim, mac} of adiumServiceId then
					set aim of theInfo to contactLogin
				else if serviceName is (icq of adiumServiceId) then
					set icq of theInfo to contactLogin
				else if serviceName is (msn of adiumServiceId) then
					set msn of theInfo to contactLogin
				else if serviceName is (yim of adiumServiceId) then
					set yim of theInfo to contactLogin
				else if serviceName is in {jab, gtalk} of adiumServiceId then
					set jab of theInfo to contactLogin
				else
					my myLog("** Unknown service: " & serviceName, 0)
				end if
			end tell
			exit repeat
		end repeat
	end tell
	return theInfo
end get_adium_person_details

on get_ab_person_details(thePersonID)
	
	set theInfo to {|name|:"", nick:"", |picture|:"", aim:{}, icq:{}, msn:{}, yim:{}, jab:{}}
	
	-- Address Book picture filename is the first part of the person ID
	-- "F732C918-8776-11D9-B6ED-000D9331DD3A:ABPerson"
	set AppleScript's text item delimiters to ":"
	set thePictureFilename to text item 1 of thePersonID -- split(:)[0]
	set AppleScript's text item delimiters to ""
	
	tell application "Address Book"
		repeat with thePerson in (every person whose id is thePersonID)
			tell thePerson
				set |name| of theInfo to name
				set nick of theInfo to nickname
				set |picture| of theInfo to abPicturesFolder & thePictureFilename
				if (count AIM handles) is not 0 then set aim of theInfo to (value of AIM handles)
				if (count ICQ handles) is not 0 then set icq of theInfo to (value of ICQ handles)
				if (count MSN handles) is not 0 then set msn of theInfo to (value of MSN handles)
				if (count Yahoo handles) is not 0 then set yim of theInfo to (value of Yahoo handles)
				if (count Jabber handles) is not 0 then set jab of theInfo to (value of Jabber handles)
			end tell
			exit repeat
		end repeat
	end tell
	return theInfo
end get_ab_person_details

on get_ab_person_emails(thePersonID)
	tell application "Address Book"
		set theEmails to value of emails of (every person whose id is thePersonID)
	end tell
	if theEmails is not {} then set theEmails to item 1 of theEmails
	return theEmails
end get_ab_person_emails

on set_ab_im(abPerson, imService, imLogin)
	tell application "Address Book"
		tell (the first person whose id is abPerson)
			if imService is in {aim, mac} of adiumServiceId then
				make new AIM Handle at end of AIM handles with properties {label:abImDefaultLabel, value:imLogin}
			else if imService is (icq of adiumServiceId) then
				make new ICQ handle at end of ICQ handles with properties {label:abImDefaultLabel, value:imLogin}
			else if imService is (msn of adiumServiceId) then
				make new MSN handle at end of MSN handles with properties {label:abImDefaultLabel, value:imLogin}
			else if imService is (yim of adiumServiceId) then
				make new Yahoo handle at end of Yahoo handles with properties {label:abImDefaultLabel, value:imLogin}
			else if imService is in {jab, gtalk} of adiumServiceId then
				make new Jabber handle at end of Jabber handles with properties {label:abImDefaultLabel, value:imLogin}
			end if
		end tell
	end tell
end set_ab_im

on copy_adium_picture_to_ab(adiumPerson, abPerson)
	try
		-- Get Adium picture from local folder (they removed the image property on v1.2...)
		set picturePath to |picture| of get_adium_person_details(|id| of adiumPerson, nick of adiumPerson)
		set pictureData to read (picturePath as POSIX file) as TIFF picture
		-- Set it in AB
		tell application "Address Book" to set image of first person whose id is abPerson to pictureData
	end try
end copy_adium_picture_to_ab

-- Format and show up person info (name, picture, etc) on the screen
-- XXX It doesn't use clear_details() because doing "by hand" it appears to be faster for the user

on set_person_details_on_screen(theView, theInfo)
	--myLog("action: set details on screen", 2)
	
	set viewName to (name of theView as text)
	
	-- Append quoted nick after name (if any)
	if nick of theInfo is not "" and nick of theInfo is not missing value then
		set |name| of theInfo to |name| of theInfo & return & "\"" & nick of theInfo & "\""
	end if
	
	-- Update screen (note: no "clear" before)
	tell box "details" of theView
		
		-- Order matters (on slow computers)
		
		-- Documentation said we must always del the references manually
		delete image of image view "picture"
		delete tool tip of button "reveal_finder"
		set enabled of button "reveal_finder" to false
		try
			set image of image view "picture" to load image |picture| of theInfo
			set tool tip of button "reveal_finder" to |picture| of theInfo
			set enabled of button "reveal_finder" to true
		end try
		
		set content of text field "name" to |name| of theInfo
		
		-- Toolbar buttons states
		if viewName is "adium" then
			set enabled of button "search_ab" to true
			set tool tip of button "search_ab" to tooltipFindInAb
			
			-- Always enabled, the test is made when pressed (or when Find in AB is used)
			set enabled of button "add_to_ab" to true
			set tool tip of button "add_to_ab" to tooltipAddToAb
			
			-- Always enabled as we will always have an IM login
			set enabled of button "set_ab_im" to true
			set tool tip of button "set_ab_im" to tooltipSetAbIm
			
			-- "set picture" only enabled if contact has image
			if (exists image of image view "picture") then
				set enabled of button "set_ab_picture" to true
				set tool tip of button "set_ab_picture" to tooltipSetAbPicture
			else
				set enabled of button "set_ab_picture" to false
				delete tool tip of button "set_ab_picture"
			end if
		else
			set enabled of button "search_adium" to true
			set tool tip of button "search_adium" to tooltipFindInAdium
			
			set enabled of button "reveal_ab" to true
			set tool tip of button "reveal_ab" to tooltipRevealInAb
		end if
		
		-- The IM's logins
		if viewName is "adium" then
			
			-- Turn service icons and contents On/Off in a sequence
			set enabled of button "aim" to (aim of theInfo is not "")
			set content of text field "aim" to aim of theInfo
			
			set enabled of button "icq" to (icq of theInfo is not "")
			set content of text field "icq" to icq of theInfo
			
			set enabled of button "msn" to (msn of theInfo is not "")
			set content of text field "msn" to msn of theInfo
			
			set enabled of button "yim" to (yim of theInfo is not "")
			set content of text field "yim" to yim of theInfo
			
			set enabled of button "jab" to (jab of theInfo is not "")
			set content of text field "jab" to jab of theInfo
			
		else
			-- Clear pop ups			
			delete every menu item of menu of every popup button
			
			-- Set service icons state
			set enabled of button "aim" to (aim of theInfo is not {})
			set enabled of button "icq" to (icq of theInfo is not {})
			set enabled of button "msn" to (msn of theInfo is not {})
			set enabled of button "yim" to (yim of theInfo is not {})
			set enabled of button "jab" to (jab of theInfo is not {})
			
			-- Populate pop ups
			-- Show and populate popup if one or more items, show item count if > 1
			set i to count aim of theInfo
			set visible of popup button "aim" to (i > 0)
			if i is greater than 0 then my populate_popup(popup button "aim", aim of theInfo)
			if i is less than 2 then set i to ""
			set content of text field "aim" to i
			
			set i to count icq of theInfo
			set visible of popup button "icq" to (i > 0)
			if i is greater than 0 then my populate_popup(popup button "icq", icq of theInfo)
			if i is less than 2 then set i to ""
			set content of text field "icq" to i
			
			set i to count msn of theInfo
			set visible of popup button "msn" to (i > 0)
			if i is greater than 0 then my populate_popup(popup button "msn", msn of theInfo)
			if i is less than 2 then set i to ""
			set content of text field "msn" to i
			
			set i to count yim of theInfo
			set visible of popup button "yim" to (i > 0)
			if i is greater than 0 then my populate_popup(popup button "yim", yim of theInfo)
			if i is less than 2 then set i to ""
			set content of text field "yim" to i
			
			set i to count jab of theInfo
			set visible of popup button "jab" to (i > 0)
			if i is greater than 0 then my populate_popup(popup button "jab", jab of theInfo)
			if i is less than 2 then set i to ""
			set content of text field "jab" to i
		end if
	end tell
	
	-- Donate reminder check
	set statsTotal to counterSearch + counterReport + counterSet + counterAdd
	if statsTotal is greater than 0 and (statsTotal mod donateReminderInterval) is 0 and statsTotal is greater than lastReminder and magicWord is not add_x("") then
		set lastReminder to statsTotal
		display alert "AdiumBook - What a time saver!" as warning message get_stats_report() & return & return & "How much does it cost ONE hour of your life? What about giving something back to support AdiumBook development?" & return default button "Donate Now" alternate button "Later" attached to window "main"
		save_defaults()
	end if
	
end set_person_details_on_screen

on get_person_details_from_screen(theView)
	--myLog("action: get details from screen", 2)
	
	set theInfo to {|id|:"", |name|:"", nick:"", |picture|:"", aim:"", icq:"", msn:"", yim:"", jab:""}
	set viewName to (name of theView as text)
	
	tell box "details" of theView
		if viewName is "Adium" then
			set aim of theInfo to content of text field "aim"
			set icq of theInfo to content of text field "icq"
			set msn of theInfo to content of text field "msn"
			set yim of theInfo to content of text field "yim"
			set jab of theInfo to content of text field "jab"
		else
			set aim of theInfo to title of menu items of menu of popup button "aim"
			set icq of theInfo to title of menu items of menu of popup button "icq"
			set msn of theInfo to title of menu items of menu of popup button "msn"
			set yim of theInfo to title of menu items of menu of popup button "yim"
			set jab of theInfo to title of menu items of menu of popup button "jab"
		end if
	end tell
	
	return theInfo
	
	--set |name| of theInfo to content of text field "name" of theView
	--set |picture| of theInfo to image of image view "picture" of theView
	-- XXX put nick on a separate box?	No, keep the current "nick overflow" if big name
end get_person_details_from_screen

on get_selected_person_id(theView)
	try
		set theRow to selected data row of table view 1 of scroll view 1 of theView
		return contents of data cell "id" of theRow
	on error
		return ""
	end try
end get_selected_person_id

on get_selected_person_info(theView)
	set theInfo to {|id|:"", nick:"", |name|:""}
	try
		set theRow to selected data row of table view 1 of scroll view 1 of theView
		set |id| of theInfo to contents of data cell "id" of theRow
		set nick of theInfo to contents of data cell "nick" of theRow
		set |name| of theInfo to contents of data cell "name" of theRow
	end try
	return theInfo
end get_selected_person_info

-- Select the first table entry and show his/her details
on auto_show_first_result(theView)
	--myLog("action: auto show first result", 2)
	
	-- Exit if the table is empty
	if (count of data rows of data source of table view 1 of scroll view 1 of theView) is 0 then return
	
	-- Selects and get the ID of the first contact
	set selected row of table view 1 of scroll view 1 of theView to 1
	delay 0.1 -- Oh my... AS needs time to really select the row ;)
	set personID to contents of data cell "id" of selected data row of table view 1 of scroll view 1 of theView
	set personLogin to contents of data cell "nick" of selected data row of table view 1 of scroll view 1 of theView
	
	-- Show his/her details
	if (name of theView as text) is "adium" then
		set personInfo to get_adium_person_details(personID, personLogin)
	else
		set personInfo to get_ab_person_details(personID)
	end if
	set_person_details_on_screen(theView, personInfo)
	
end auto_show_first_result


on show_details_for_selected_result(theObject)
	--myLog("action: show contact details", 2)
	
	-- Get person ID of the selected row
	if selected data rows of theObject is {} then return -- no row selected
	set personID to contents of data cell "id" of selected data row of theObject
	set contactLogin to contents of data cell "nick" of selected data row of theObject
	
	-- Get the contact's info and show on screen
	if (id of theObject) is equal to (id of table view 1 of scroll view 1 of adiumView) then
		set personInfo to get_adium_person_details(personID, contactLogin)
		set_person_details_on_screen(adiumView, personInfo)
	else
		set personInfo to get_ab_person_details(personID)
		set_person_details_on_screen(abView, personInfo)
	end if
end show_details_for_selected_result

---------------------------------------------------------------------------------------

(*   INIT order:
- will finish launching
- awake from nib
- launched
- will become active
- activated
- idle
*)

on will finish launching theObject
	--myLog("event: will finish launching", 1)
	(*
	User Defaults:
	In AppleScript Studio, global and property values are not retained between program executions.
	So we need to use User Defaults (XML preferences) instead.
	Read the values now, periodic automatic saving on program execution, force save on "will quit".
	
	From the docs: Use make before reading a default. You do not have to worry that this will replace any existing user preferences, because if you attempt to make a new entry for a key that already exists, no new entry is created and the value for the key is not changed.
	*)
	
	-- Create user defaults
	make new default entry at end of default entries of user defaults with properties {name:"counterSearch", contents:0}
	make new default entry at end of default entries of user defaults with properties {name:"counterReport", contents:0}
	make new default entry at end of default entries of user defaults with properties {name:"counterSet", contents:0}
	make new default entry at end of default entries of user defaults with properties {name:"counterAdd", contents:0}
	make new default entry at end of default entries of user defaults with properties {name:"magic", contents:""}
	
	-- Read
	set counterSearch to contents of default entry "counterSearch" of user defaults as integer
	set counterReport to contents of default entry "counterReport" of user defaults as integer
	set counterSet to contents of default entry "counterSet" of user defaults as integer
	set counterAdd to contents of default entry "counterAdd" of user defaults as integer
	set magicWord to contents of default entry "magic" of user defaults as text
	
end will finish launching

-- Init process: set global properties and create/link the data sources
on awake from nib theObject
	--myLog("event: awake from nib", 1)
	
	-- Check Adium version
	set currentAdiumVersion to version of application "Adium" as string
	if currentAdiumVersion is less than requiredAdiumVersion then
		display alert msgWrongAdiumVersion as warning message msgWrongAdiumVersionDetails & return & return & "Expected Adium version " & requiredAdiumVersion & ", got " & currentAdiumVersion default button "Quit" attached to window "main"
		return
	end if
	
	-- Setting here works fine. Setting on property definition gets MY home path hardcoded...
	--set adiumPicturesFolder to POSIX path of (path to library folder from user domain) & "Caches/Adium/Default/"
	set abPicturesFolder to POSIX path of (path to application support from user domain) & "AddressBook/Images/"
	set adiumContactPicturePath to do shell script "mktemp -t AdiumBook"
	
	-- Handy shortcuts for each half of the screen
	set adiumView to view "adium" of split view 1 of window "main"
	set abView to view "ab" of split view 1 of window "main"
	
	-- Create data sources
	set adiumDataSource to make new data source at end of data sources with properties {name:"adium_table"}
	set abDataSource to make new data source at end of data sources with properties {name:"ab_table"}
	
	-- Create all the columns for each data source
	-- Note: The column name has to be the same as in Interface Builder "AppleScript" pane.
	tell adiumDataSource
		make new data column at the end of data columns with properties {name:"id"}
		make new data column at the end of data columns with properties {name:"nick", sort order:ascending, sort type:alphabetical, sort case sensitivity:case insensitive}
		make new data column at the end of data columns with properties {name:"name", sort order:ascending, sort type:alphabetical, sort case sensitivity:case insensitive}
		set sorted to true
		set sort column to data column "name"
	end tell
	tell abDataSource
		make new data column at the end of data columns with properties {name:"id"}
		make new data column at the end of data columns with properties {name:"nick", sort order:ascending, sort type:alphabetical, sort case sensitivity:case insensitive}
		make new data column at the end of data columns with properties {name:"name", sort order:ascending, sort type:alphabetical, sort case sensitivity:case insensitive}
		set sorted to true
		set sort column to data column "name"
	end tell
	--myLog("init: data sources created", 2)
	
	-- Connect our new (empty) data sources to the tale views
	set data source of table view 1 of scroll view 1 of adiumView to adiumDataSource
	set data source of table view 1 of scroll view 1 of abView to abDataSource
	--myLog("init: data sources linked to table views", 2)
	
	-- set total count & adium status
	set_box_totals(adiumView, 0)
	set_box_totals(abView, 0)
	set_adium_status()
	--myLog("init: contacts count & Adium status OK", 2)
	
	-- load the Quack
	set quack to load sound "Inflate"
	
	-- Initialize & Populate tables
	search_adium("")
	search_ab("")
	--myLog("init: done", 2)
	
end awake from nib


-- Button or table clicked

on clicked theObject
	--myLog("event: clicked", 1)
	
	if name of theObject is "results" then
		--myLog("clicked: table row", 1)
		
		show_details_for_selected_result(theObject)
		
	else if name of theObject is "search_adium" then
		--myLog("clicked: button search in adium", 1)
		--myLog("action: search AB contact in Adium", 2)
		
		-- Get the info of the current AB contact
		set rowInfo to get_selected_person_info(abView)
		if rowInfo is "" then return -- no row selected
		set theData to get_person_details_from_screen(abView)
		set |id| of theData to |id| of rowInfo
		set nick of theData to nick of rowInfo
		set |name| of theData to |name| of rowInfo
		
		-- Attention to the command order (fine tunned, appears to be faster)
		-- Leave all non user-noticeable commands to the end
		set_adium_status()
		start progress indicator "progress" of adiumView
		
		clear_details(adiumView)
		clear_search(adiumView)
		set_status_bar(adiumView, "Searching...")
		
		-- Compose the list of patterns
		set searchPatterns to (aim of theData) & (icq of theData) & (msn of theData) & (yim of theData) & (jab of theData)
		set searchPatterns to searchPatterns & get_ab_person_emails(|id| of theData)
		set the end of searchPatterns to |name| of theData
		set the end of searchPatterns to nick of theData
		set searchPatterns to remove_empty_items(remove_dups_from_list(searchPatterns))
		--myLog(searchPatterns, 2)
		
		-- Search for all patterns in Adium, remove duplicates and populate table
		set searchResults to {}
		repeat with searchPattern in searchPatterns
			set searchResults to searchResults & search_adium_by_text(searchPattern)
		end repeat
		populate_table(adiumView, remove_dups_from_datasource_record(searchResults))
		
		auto_show_first_result(adiumView)
		set_status_bar(adiumView, "Search AB contact in Adium")
		stop progress indicator "progress" of adiumView
		set counterSearch to counterSearch + 1
		
	else if name of theObject is "search_ab" then
		--myLog("action: user search in ab", 1)
		
		-- Get contact info for the selected row
		set adiumInfo to get_selected_person_info(adiumView)
		if adiumInfo is "" then return -- no row selected
		set contactLogin to nick of adiumInfo
		set contactName to |name| of adiumInfo
		
		--myLog("AB search pattern: " & contactLogin & ", " & contactName, 3)
		
		start progress indicator "progress" of abView
		clear_details(abView)
		clear_search(abView)
		set_status_bar(abView, "Searching...")
		set searchResults to search_ab_text(contactLogin) & search_ab_text(contactName)
		populate_table(abView, remove_dups_from_datasource_record(searchResults))
		auto_show_first_result(abView)
		set_status_bar(abView, "Search Adium contact in AB")
		stop progress indicator "progress" of abView
		set counterSearch to counterSearch + 1
		
		-- If found on AB, disable de ADD button
		if item 1 of get_box_totals(abView) is greater than 0 then
			disable_button("add_to_ab", adiumView)
		end if
		
	else if name of theObject starts with "set_ab_" then
		--myLog("action: set AB Info", 1)
		
		set adiumPerson to get_selected_person_info(adiumView)
		set abPerson to get_selected_person_id(abView)
		if abPerson is "" then
			display alert msgSelectPersonToSetAbInfo as warning message msgSelectPersonToSetAbInfoDetails attached to window "main"
		else
			if name of theObject is "set_ab_picture" then
				--myLog("action: will set Picture", 2)
				
				copy_adium_picture_to_ab(adiumPerson, abPerson)
				
			else if name of theObject is "set_ab_im" then
				--myLog("action: will set IM", 2)
				
				set serviceName to get_adium_service(|id| of adiumPerson)
				set contactLogin to nick of adiumPerson
				set_ab_im(abPerson, serviceName, contactLogin)
				
			else
				myLog("** Unknown button pressed: " & name of theObject, 0)
			end if
			set_person_details_on_screen(abView, get_ab_person_details(abPerson))
			set counterSet to counterSet + 1
		end if
		
	else if name of theObject is "reveal_ab" then
		--myLog("action: Reveal contact in AB", 1)
		
		-- Get person ID of the selected row
		set personID to get_selected_person_id(abView)
		if personID is "" then return -- no row selected
		
		tell application "Address Book"
			set selection to person id personID
			activate
		end tell
		
	else if name of theObject is "add_to_ab" then
		--myLog("action: Add contact to AB", 1)
		
		set adiumPerson to get_selected_person_info(adiumView)
		set theService to get_adium_service(|id| of adiumPerson)
		set theLogin to nick of adiumPerson
		
		if search_ab_by_service_test(theService, theLogin) then
			display alert msgPersonAlreadyInAb as warning message msgPersonAlreadyInAbDetails attached to window "main"
			disable_button("add_to_ab", adiumView)
			
		else
			-- Preparing...
			start progress indicator "progress" of abView
			clear_details(abView)
			clear_search(abView)
			set_status_bar(abView, "Adding new contact...")
			
			set adiumInfo to get_selected_person_info(adiumView)
			set theInfo to get_adium_person_details(|id| of adiumInfo, nick of adiumInfo)
			
			-- Add the new contact to AB (with name), then set IM and picture
			tell application "Address Book"
				set newContact to make new person with properties {first name:|name| of theInfo}
				set abPerson to id of newContact
			end tell
			set_ab_im(abPerson, theService, theLogin)
			copy_adium_picture_to_ab(adiumPerson, abPerson)
			tell application "Address Book" to save addressbook
			
			-- Contact added. Now fill table with him/her and show the details
			populate_table(abView, {{|id|:abPerson, nick:"", |name|:|name| of theInfo}})
			auto_show_first_result(abView)
			set_status_bar(abView, "New contact added")
			
			stop progress indicator "progress" of abView
			set counterAdd to counterAdd + 1
			
			-- Finally disable the ADD button
			disable_button("add_to_ab", adiumView)
		end if
		
	else if name of theObject is "reveal_finder" then
		--myLog("action: reveal picture in finder", 1)
		--myLog(tool tip of theObject, 2)
		
		set theFile to tool tip of theObject
		tell application "Finder"
			reveal (theFile as POSIX file)
			activate
		end tell
		
	else if name of theObject is "ab_icon" then
		--myLog("action: bring AB to front", 1)
		
		tell application "Address Book" to activate
		
	else if name of theObject is "adium_icon" then
		--myLog("action: quack!", 1)
		
		if adiumOnline then
			-- Toggle Adiumy flapping
			if adiumFlapping then
				set image of button "adium_icon" of adiumView to load image "adium-online"
				set adiumFlapping to false
			else
				set image of button "adium_icon" of adiumView to load image "adium-flap"
				play quack
				set adiumFlapping to true
			end if
		end if
		set_adium_status()
		
	end if
end clicked


-- Search box

on action theObject
	--myLog("event: action", 1)
	
	if name of theObject is "search" then
		set theSearchText to content of theObject as text
		
		if (id of theObject) is equal to (id of text field "search" of adiumView) then
			set_adium_status()
			search_adium(theSearchText)
		else
			search_ab(theSearchText)
		end if
		set counterSearch to counterSearch + 1
	end if
end action


-- Key pressed inside table

on keyboard down theObject event theEvent
	--myLog("event: keyboard down", 1)
	
	if key code of theEvent is in {52, 36, 49, 76} then -- ENTER, RETURN, SPACE, ENTER (Fn+return)
		--myLog("action: get user details", 1)
		show_details_for_selected_result(theObject)
	end if
end keyboard down


-- Menu item clicked

on choose menu item theObject
	--myLog("event: choose menu item", 1)
	
	if name of theObject is "report_not_in_ab" then
		set reportName to title of theObject
		--myLog("action: report " & reportName, 1)
		
		clear_details(adiumView)
		clear_search(adiumView)
		set_status_bar(adiumView, "Report: " & reportName)
		set maximum value of progress indicator "progress_report" of adiumView to item 2 of adiumContacts
		populate_table(adiumView, search_report_not_in_ab())
		set content of progress indicator "progress_report" of adiumView to 0
		stop progress indicator "progress_report" of adiumView
		auto_show_first_result(adiumView)
		set_adium_status()
		
	else if name of theObject is "report_not_in_adium" then
		set reportName to title of theObject
		--myLog("action: report " & reportName, 1)
		
		clear_details(abView)
		clear_search(abView)
		set_status_bar(abView, "Report: " & reportName)
		set maximum value of progress indicator "progress_report" of abView to item 2 of abContacts
		populate_table(abView, search_report_not_in_adium())
		set content of progress indicator "progress_report" of abView to 0
		stop progress indicator "progress_report" of abView
		auto_show_first_result(abView)
		set_adium_status()
		
	else if name of theObject is "report_no_im" then
		set reportName to title of theObject
		--myLog("action: report " & reportName, 1)
		
		start progress indicator "progress" of abView
		clear_details(abView)
		clear_search(abView)
		set_status_bar(abView, "Report: " & reportName)
		populate_table(abView, search_report_ab_no_im())
		auto_show_first_result(abView)
		stop progress indicator "progress" of abView
		
	else if name of theObject is "report_no_picture" then
		set reportName to title of theObject
		--myLog("action: report " & reportName, 1)
		
		start progress indicator "progress" of abView
		clear_details(abView)
		clear_search(abView)
		set_status_bar(abView, "Report: " & reportName)
		populate_table(abView, search_report_ab_no_picture())
		auto_show_first_result(abView)
		stop progress indicator "progress" of abView
		
	else if name of theObject starts with "report_ab_service_" then
		
		set serviceID to (items -3 thru -1 of (name of theObject as text) as text)
		set reportName to title of theObject
		--myLog("action: report " & reportName, 1)
		
		start progress indicator "progress" of abView
		clear_details(abView)
		clear_search(abView)
		set_status_bar(abView, "Report: " & reportName)
		populate_table(abView, search_report_ab_with_service(serviceID))
		auto_show_first_result(abView)
		stop progress indicator "progress" of abView
		
	else if name of theObject is "stats" then
		--myLog("action: stats", 1)
		
		display alert "Your Statistics" as warning message get_stats_report() attached to window "main"
		save_defaults() -- Since we've stopped, let's make something useful...
		
	else if name of theObject is "donate" then
		--myLog("action: donate", 1)
		
		display alert "Donate to AdiumBook" as warning message "Donating (any amount) to the AdiumBook project you will help me to create new features and keep this application updated with the fast Adium development." & return & return & "AdiumBook is a one-man spare-time effort." & return & "My name is Aurelio, born 1977, brazilian." & return & "Support people." default button "Donate Now" alternate button "Later" attached to window "main"
		save_defaults() -- Since we've stopped, let's make something useful...
		
	else if name of theObject is "website" then
		--myLog("action: website", 1)
		
		open location myUrl
		save_defaults() -- Since we've switched focus, let's make something useful...
		
	else if name of theObject is "iusethis" then
		--myLog("action: website", 1)
		
		open location iusethisUrl
		save_defaults() -- Since we've switched focus, let's make something useful...
		
	else if name of theObject is "issue" then
		--myLog("action: issue", 1)
		
		open location issueUrl
		save_defaults() -- Since we've switched focus, let's make something useful...
		
	end if
	
	if name of theObject starts with "report_" then set counterReport to counterReport + 1
	
end choose menu item


-- Sort column
-- Note: code copied verbatim from Apple docs (almost verbatim: s/identifier/name/)

on column clicked theObject table column tableColumn
	--myLog("event: column clicked", 1)
	
	set theDataSource to data source of theObject
	set theColumnIdentifier to name of tableColumn
	set theSortColumn to sort column of theDataSource
	-- If clicked column is different from the current sort column, switch the sort
	if (name of theSortColumn) is not equal to theColumnIdentifier then
		set the sort column of theDataSource to data column theColumnIdentifier of theDataSource
	else
		-- Otherwise change the sort order
		if sort order of theSortColumn is ascending then
			set sort order of theSortColumn to descending
		else
			set sort order of theSortColumn to ascending
		end if
	end if
	-- Update the table view (so it will be redrawn)
	update theObject
end column clicked

on alert ended theObject with reply withReply
	--myLog("event: alert ended", 1)
	
	if button returned of withReply is "Donate Now" then
		--myLog("alert button: donate", 1)
		open location donateUrl
		
	else if button returned of withReply is "Quit" then
		tell me to quit
	end if
	
end alert ended

-- Quit program if window is closed
on will close theObject
	--myLog("event: will close", 1)
	tell me to quit
end will close

-- Note: If "Force quit (SIGTERM)", this code will not be executed
on will quit theObject
	--myLog("event: will quit", 1)
	save_defaults()
end will quit

on right mouse up theObject event theEvent
	--myLog("event: right mouse up", 1)
	
	set the clipboard to (title of current menu item of theObject as text)
end right mouse up

on selection changed theObject
	--myLog("event: selection changed", 1)
	
	-- Tried do attach details update here, but fast changes (scrolling) messes it all
	-- show_details_for_selected_result(theObject)
	
	-- So we just clear the details, it's fast
	if (id of theObject) is equal to (id of table view 1 of scroll view 1 of adiumView) then
		clear_details(adiumView)
	else
		clear_details(abView)
	end if
	
end selection changed
