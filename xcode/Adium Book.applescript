-- Adium Book.applescript
-- Adium Book

--  Created by Aurelio Marinho Jargas on Sun Jul 10 2005.
--  License: MIT, Open Source, GPL, whatever. Pick your favorite.
--  More info: http://aurelio.net/bin/as/

-- TODO improved image report (to obsolete my adium script)
-- TODO Find button: search for name/nick also (only if none found?)

(* 
						Code Overview

The interface is splitted in two parts (views): Adium at left and Address Book
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
- Chosing an item on Reports menu (to make a report search)

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
			

Adium versions
	
	< 0.84:
		- Service IDs: AIM, Mac, ICQ, MSN, Yahoo, Jabber
		- set adiumStatus to my status of the first Adium controller
		

	>= 0.84:
		- Service IDs: AIM, Mac, ICQ, MSN, Yahoo!, Jabber
		- set adiumStatus to my status type of the first Adium controller


Tip: Monitor execution with Console.app to track for AB and Adium warnings

*)

-- The only properties that you may want to change
property theLogLevel : 0 -- Zero: no log, 1: informative log, 2: detailed log, 3: ugly log
property abImDefaultLabel : "home" -- Used by the "Set IM" button (home, work, other)


-- These are set on "awake from nib"
property adiumView : ""
property abView : ""
property adiumPicturesFolder : ""
property abPicturesFolder : ""
property adiumContacts : {0, 0} -- Found / Total
property abContacts : {0, 0}
property adiumOnline : true -- Changing here changes nothing
property adiumServiceId : {aim:"AIM", mac:"Mac", icq:"ICQ", msn:"MSN", yim:"Yahoo!", jab:"Jabber", gtalk:"GTalk"}

-- Some random text
property myVersion : "1.2"
property myUrl : "http://aurelio.net/bin/as/adiumbook/"
property adiumUrl : "http://www.adiumx.com"
property donateUrl : "https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=verde%40aurelio%2enet&item_name=Adium%20Book&no_shipping=1&return=http%3a%2f%2faurelio%2enet%2fdonate%2dthanks%2ehtml&cn=Please%20leave%20a%20comment%20to%20me&tax=0&currency_code=USD&bn=PP%2dDonationsBF&charset=UTF%2d8"

property tooltipAdiumOffline : "Adium is Offline. Please login or you'll have poor search results."
property tooltipFindInAb : "Find this contact in Address Book"
property tooltipFindInAdium : "Find this contact in Adium"
property tooltipRevealInAb : "Reveal this contact's card in Address Book"
property tooltipAddToAb : "Create a NEW CARD for this contact in Address Book"
property tooltipSetAbIm : "Set the IM field in Address Book"
property tooltipSetAbPicture : "Set the PICTURE in Address Book"

property msgSelectPersonToSetAbInfo : "No contact selected in Address Book."
property msgSelectPersonToSetAbInfoDetails : "To set somebody's IM or picture, first you need to select the contact on the Address Book view."
property msgPersonAlreadyInAb : "This contact is already added."
property msgPersonAlreadyInAbDetails : "This contact already has a card on your Address Book. Press the Find button to see it."

----------------------------------------------------------------------------------

on myLog(theMessage, theLevel)
	if theLevel is not greater than theLogLevel then log (theMessage)
end myLog

-- It is a split(".", 1) on Adium person UID
-- Sample IDs: MSN.foo@bar.com, ICQ.123456
on split_service_login(theID)
	set AppleScript's text item delimiters to "."
	set theService to text item 1 of theID
	set theLogin to ((text items 2 thru -1 of theID) as text)
	set AppleScript's text item delimiters to ""
	return {theService, theLogin}
end split_service_login

on compose_adium_search_patterns(theData)
	set searchPatterns to {}
	if icq of theData is not "" then set the end of searchPatterns to icq of adiumServiceId & "." & icq of theData
	if msn of theData is not "" then set the end of searchPatterns to msn of adiumServiceId & "." & msn of theData
	if yim of theData is not "" then set the end of searchPatterns to yim of adiumServiceId & "." & yim of theData
	if jab of theData is not "" then
		set the end of searchPatterns to jab of adiumServiceId & "." & jab of theData
		set the end of searchPatterns to gtalk of adiumServiceId & "." & jab of theData
	end if
	if aim of theData is not "" then
		set the end of searchPatterns to aim of adiumServiceId & "." & aim of theData
		set the end of searchPatterns to mac of adiumServiceId & "." & aim of theData
	end if
	myLog(searchPatterns, 3)
	return searchPatterns
end compose_adium_search_patterns

on set_adium_status()
	set currentStatus to adiumOnline
	tell application "Adium"
		set adiumStatus to my status type of the first Adium controller
		set adiumOnline to adiumStatus is not offline
	end tell
	if adiumOnline is not currentStatus then
		if not adiumOnline then
			set image of image view "adium icon" of adiumView to load image "adium-offline"
			set tool tip of image view "adium icon" of adiumView to tooltipAdiumOffline
		else
			set image of image view "adium icon" of adiumView to load image "adium"
			delete tool tip of image view "adium icon" of adiumView
		end if
	end if
end set_adium_status

on set_status_bar(theView, theMessage)
	set content of text field "status bar" of theView to theMessage
end set_status_bar

on set_box_totals(theView, currentCount)
	if name of theView as text is "adium" then
		tell application "Adium" to set theTotal to count (ID of every contact)
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
	set viewName to (name of theView as text)
	tell box "details" of theView
		
		-- order matters! (on slow computers)
		if viewName is "adium" then
			set enabled of button "add_to_ab" to false
			set enabled of button "set_ab_im" to false
			set enabled of button "set_ab_picture" to false
			set enabled of button "search_ab" to false
			delete tool tip of button "add_to_ab"
			delete tool tip of button "set_ab_im"
			delete tool tip of button "set_ab_picture"
			delete tool tip of button "search_ab"
		else
			set enabled of button "reveal_ab" to false
			set enabled of button "search_adium" to false
			delete tool tip of button "reveal_ab"
			delete tool tip of button "search_adium"
		end if
		
		delete image of image view "picture"
		delete contents of text field "name"
		delete tool tip of image view "picture"
		
		set enabled of button "aim" to false
		set enabled of button "icq" to false
		set enabled of button "msn" to false
		set enabled of button "yim" to false
		set enabled of button "jab" to false
		
		delete contents of text field "aim"
		delete contents of text field "icq"
		delete contents of text field "msn"
		delete contents of text field "yim"
		delete contents of text field "jab"
	end tell
end clear_details

on clear_table(theView)
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
	clear_details(adiumView)
	clear_table(adiumView)
	start progress indicator "progress" of adiumView
	set_status_bar(adiumView, "Searching...")
	populate_table(adiumView, search_adium_by_text(theSearchText))
	set_status_bar(adiumView, "Search results")
	auto_show_first_result(adiumView)
	stop progress indicator "progress" of adiumView
end search_adium

on search_ab(theSearchText)
	clear_details(abView)
	clear_table(abView)
	start progress indicator "progress" of abView
	set_status_bar(abView, "Searching...")
	populate_table(abView, search_ab_by_text(theSearchText))
	set_status_bar(abView, "Search results")
	auto_show_first_result(abView)
	stop progress indicator "progress" of abView
end search_ab

on search_adium_by_id_test(theID)
	set found to 0
	tell application "Adium" to set found to count of (every contact whose ID is theID)
	return found is greater than 0
end search_adium_by_id_test

-- XXX Usually just one person. Maybe it is faster to do a repeat?
on search_adium_by_id(theID)
	tell application "Adium"
		set theResults to {ID, UID, display name} of (every contact whose ID is theID)
	end tell
	return convert_results_to_datasource_record(theResults)
end search_adium_by_id

on search_ab_by_service_test(theService, theLogin)
	set found to 0
	tell application "Address Book"
		-- There is any contact using this IM id?
		if theService is in {aim, mac} of adiumServiceId then
			set found to count (every person whose (value of AIM handles) contains theLogin)
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

on search_ab_by_service(theService, theLogin)
	set theResults to {}
	set thePeople to {}
	tell application "Address Book"
		-- There is any contact using this IM id?
		if theService is in {aim, mac} of adiumServiceId then
			set thePeople to (every person whose (value of AIM handles) contains theLogin)
		else if theService is (icq of adiumServiceId) then
			set thePeople to (every person whose (value of ICQ handles) contains theLogin)
		else if theService is (msn of adiumServiceId) then
			set thePeople to (every person whose (value of MSN handles) contains theLogin)
		else if theService is (yim of adiumServiceId) then
			set thePeople to (every person whose (value of Yahoo handles) contains theLogin)
		else if theService is in {jab, gtalk} of adiumServiceId then
			set thePeople to (every person whose (value of Jabber handles) contains theLogin)
		else
			my myLog("** Unknown service: " & theService, 1)
		end if
		repeat with thisPerson in thePeople
			tell thisPerson to set the end of theResults to {|id|:id, nick:nickname, |name|:name}
		end repeat
	end tell
	return theResults
end search_ab_by_service



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

on search_adium_by_text(theSearchText)
	tell application "Adium"
		if theSearchText is not "" then
			set theResults to {ID, UID, display name} of (every contact whose (UID contains theSearchText) or (display name contains theSearchText))
		else
			set theResults to {ID, UID, display name} of every contact
		end if
	end tell
	return convert_results_to_datasource_record(theResults)
end search_adium_by_text

on search_ab_by_text(theSearchText)
	tell application "Address Book"
		if theSearchText is not "" then
			set theResults to {id, nickname, name} of (every person whose (nickname contains theSearchText) or (name contains theSearchText))
		else
			set theResults to {id, nickname, name} of every person
		end if
	end tell
	return convert_results_to_datasource_record(theResults)
end search_ab_by_text

on search_report_ab_no_im()
	tell application "Address Book"
		set theResults to {id, nickname, name} of (every person whose AIM handles is {} and ICQ handles is {} and MSN handles is {} and Yahoo handles is {})
		
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
				my myLog("searching for " & name, 2)
				if not (exists image) then
					my myLog("no picture found", 3)
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
			my myLog("** Unknown service: " & theService, 1)
		end if
	end tell
	return convert_results_to_datasource_record(theResults)
end search_report_ab_with_service


-- Results a data-source-ready list of Adium people not found in AB
on search_report_not_in_ab()
	set reportResults to {}
	tell application "Adium"
		repeat with thisPerson in every contact
			tell thisPerson
				if not my search_ab_by_service_test(serviceID, UID) then
					set the end of reportResults to {|id|:ID, nick:UID, |name|:display name}
				end if
			end tell
		end repeat
	end tell
	return reportResults
	
	(*
	-- Alternative way, slightly faster
	set reportResults to {}
	tell application "Adium"
		set {theIDs, theUIDs, theNames, theServices} to {ID, UID, display name, serviceID} of every contact
	end tell
	repeat with i from 1 to (count of theServices)
		myLog("searching for " & (item i of theUIDs), 2)
		if not search_ab_by_service_test(item i of theServices, item i of theUIDs) then
			myLog("not found", 3)
			set the end of reportResults to {|id|:item i of theIDs, nick:item i of theUIDs, |name|:item i of theNames}
		end if
	end repeat
	return reportResults
	*)
end search_report_not_in_ab

-- Results a data-source-ready list of AB people not found in Adium
on search_report_not_in_adium()
	set reportResults to {}
	tell application "Address Book"
		repeat with thisPerson in every person
			tell thisPerson
				-- Search only if AB contact has at least one IM login
				if AIM handles & ICQ handles & MSN handles & Yahoo handles is not {} then
					my myLog("searching for " & name, 2)
					
					-- Compose Adium-like search patterns
					set userInfo to {aim:"", icq:"", msn:"", yim:"", jab:""}
					if AIM handles is not {} then set aim of userInfo to (value of first AIM Handle)
					if ICQ handles is not {} then set icq of userInfo to (value of first ICQ handle)
					if MSN handles is not {} then set msn of userInfo to (value of first MSN handle)
					if Yahoo handles is not {} then set yim of userInfo to (value of first Yahoo handle)
					if Jabber handles is not {} then set jab of userInfo to (value of first Jabber handle)
					set searchPatterns to my compose_adium_search_patterns(userInfo)
					
					-- Search this person in Adium
					set found to false
					repeat with searchPattern in searchPatterns
						if my search_adium_by_id_test(searchPattern) then
							set found to true
							exit repeat
						end if
					end repeat
					
					-- Person not found, add to results
					if found is false then
						my myLog("not found", 3)
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

on get_adium_person_details(thePersonID)
	
	set theInfo to {|name|:"", nick:"", |picture|:"", aim:"", icq:"", msn:"", yim:"", jab:""}
	
	tell application "Adium"
		-- XXX Strange, but in Tiger using "(first contact whose" doesn't work 
		repeat with thePerson in (every contact whose ID is thePersonID)
			tell thePerson
				set |name| of theInfo to long display name
				set |picture| of theInfo to adiumPicturesFolder & thePersonID
				if serviceID is in {aim, mac} of adiumServiceId then
					set aim of theInfo to UID
				else if serviceID is (icq of adiumServiceId) then
					set icq of theInfo to UID
				else if serviceID is (msn of adiumServiceId) then
					set msn of theInfo to UID
				else if serviceID is (yim of adiumServiceId) then
					set yim of theInfo to UID
				else if serviceID is in {jab, gtalk} of adiumServiceId then
					set jab of theInfo to UID
				else
					my myLog("** Unknown service: " & serviceID, 1)
				end if
			end tell
			exit repeat
		end repeat
	end tell
	return theInfo
end get_adium_person_details

on get_ab_person_details(thePersonID)
	
	set theInfo to {|name|:"", nick:"", |picture|:"", aim:"", icq:"", msn:"", yim:"", jab:""}
	
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
				if (count AIM handles) is not 0 then set aim of theInfo to (value of first AIM Handle)
				if (count ICQ handles) is not 0 then set icq of theInfo to (value of first ICQ handle)
				if (count MSN handles) is not 0 then set msn of theInfo to (value of first MSN handle)
				if (count Yahoo handles) is not 0 then set yim of theInfo to (value of first Yahoo handle)
				if (count Jabber handles) is not 0 then set jab of theInfo to (value of first Jabber handle)
			end tell
			exit repeat
		end repeat
	end tell
	return theInfo
end get_ab_person_details


on set_ab_im(abPerson, imService, imLogin)
	tell application "Address Book"
		tell (the first person whose id is abPerson)
			if imService is in {aim, mac} of adiumServiceId then
				if (count AIM handles) is 0 then
					make new AIM Handle at beginning of AIM handles with properties {label:abImDefaultLabel, value:imLogin}
				else
					set value of first AIM Handle to imLogin
				end if
			else if imService is (icq of adiumServiceId) then
				if (count ICQ handles) is 0 then
					make new ICQ handle at beginning of ICQ handles with properties {label:abImDefaultLabel, value:imLogin}
				else
					set value of first ICQ handle to imLogin
				end if
			else if imService is (msn of adiumServiceId) then
				if (count MSN handles) is 0 then
					make new MSN handle at beginning of MSN handles with properties {label:abImDefaultLabel, value:imLogin}
				else
					set value of first MSN handle to imLogin
				end if
			else if imService is (yim of adiumServiceId) then
				if (count Yahoo handles) is 0 then
					make new Yahoo handle at beginning of Yahoo handles with properties {label:abImDefaultLabel, value:imLogin}
				else
					set value of first Yahoo handle to imLogin
				end if
			else if imService is in {jab, gtalk} of adiumServiceId then
				if (count Jabber handles) is 0 then
					make new Jabber handle at beginning of Jabber handles with properties {label:abImDefaultLabel, value:imLogin}
				else
					set value of first Jabber handle to imLogin
				end if
			end if
		end tell
	end tell
end set_ab_im


on copy_adium_picture_to_ab(adiumPerson, abPerson)
	try
		tell application "Adium" to set thePicture to image of first contact whose ID is adiumPerson
		tell application "Address Book" to set image of first person whose id is abPerson to thePicture
	end try
end copy_adium_picture_to_ab

-- Format and show up person info (name, picture, etc) on the screen
-- XXX It doesn't use clear_details() because doing "by hand" it appears to be faster for the user

on set_person_details_on_screen(theView, theInfo)
	
	set viewName to (name of theView as text)
	
	-- Append quoted nick after name (if any)
	if nick of theInfo is not "" and nick of theInfo is not missing value then
		set |name| of theInfo to |name| of theInfo & return & "\"" & nick of theInfo & "\""
	end if
	
	-- Update screen
	tell box "details" of theView
		
		-- Order matters (on slow computers)
		
		-- Documentation said we must always del the references manually
		delete image of image view "picture"
		delete tool tip of image view "picture"
		try
			set image of image view "picture" to load image |picture| of theInfo
			set tool tip of image view "picture" to |picture| of theInfo
		end try
		
		set content of text field "name" to |name| of theInfo
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
	end tell
end set_person_details_on_screen

on get_person_details_from_screen(theView)
	
	set theInfo to {|name|:"", nick:"", |picture|:"", aim:"", icq:"", msn:"", yim:"", jab:""}
	
	set aim of theInfo to content of text field "aim" of box "details" of theView
	set icq of theInfo to content of text field "icq" of box "details" of theView
	set msn of theInfo to content of text field "msn" of box "details" of theView
	set yim of theInfo to content of text field "yim" of box "details" of theView
	set jab of theInfo to content of text field "jab" of box "details" of theView
	return theInfo
	
	--set |name| of theInfo to content of text field "name" of theView
	--set |picture| of theInfo to image of image view "picture" of theView
	-- XXX put nick on a separate box?	
end get_person_details_from_screen

on get_selected_person_id(theView)
	try
		set theRow to selected data row of table view 1 of scroll view 1 of theView
		return contents of data cell "id" of theRow
	on error
		return ""
	end try
end get_selected_person_id


-- Select the first table entry and show his/her details
on auto_show_first_result(theView)
	
	-- Exit if the table is empty
	if (count of data rows of data source of table view 1 of scroll view 1 of theView) is 0 then return
	
	-- Selects and get the ID of the first contact
	set selected row of table view 1 of scroll view 1 of theView to 1
	delay 0.1 -- Oh my... AS needs time to really select the row ;)
	set personID to contents of data cell "id" of selected data row of table view 1 of scroll view 1 of theView
	
	-- Show his/her details
	if (name of theView as text) is "adium" then
		set personInfo to get_adium_person_details(personID)
	else
		set personInfo to get_ab_person_details(personID)
	end if
	set_person_details_on_screen(theView, personInfo)
	
end auto_show_first_result


on show_details_for_selected_result(theObject)
	-- Get person ID of the selected row
	if selected data rows of theObject is {} then return -- no row selected
	set personID to contents of data cell "id" of selected data row of theObject
	
	-- Get the contact's info and show on screen
	if (id of theObject) is equal to (id of table view 1 of scroll view 1 of adiumView) then
		set personInfo to get_adium_person_details(personID)
		set_person_details_on_screen(adiumView, personInfo)
	else
		set personInfo to get_ab_person_details(personID)
		set_person_details_on_screen(abView, personInfo)
	end if
end show_details_for_selected_result
---------------------------------------------------------------------------------------

-- Init process: set global properties and create/link the data sources

on awake from nib theObject
	myLog("event: awake from nib", 1)
	
	-- Setting here works fine. Setting on property definition gets MY home path hardcoded...
	set adiumPicturesFolder to POSIX path of (path to library folder from user domain) & "Caches/Adium/Default/"
	set abPicturesFolder to POSIX path of (path to application support from user domain) & "AddressBook/Images/"
	
	-- Handy shortcuts for each half of the screen
	set adiumView to view "adium" of window "main"
	set abView to view "ab" of window "main"
	
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
	myLog("init: data sources created", 2)
	
	-- Connect our new (empty) data sources to the tale views
	set data source of table view 1 of scroll view 1 of adiumView to adiumDataSource
	set data source of table view 1 of scroll view 1 of abView to abDataSource
	myLog("init: data sources linked to table views", 2)
	
	-- set total count & adium status
	set_box_totals(adiumView, 0)
	set_box_totals(abView, 0)
	set_adium_status()
	myLog("init: contacts count & Adium status OK", 2)
	
	-- Initialize & Populate tables
	search_adium("")
	search_ab("")
	myLog("init: done", 2)
	
end awake from nib


-- Button or table clicked

on clicked theObject
	myLog("event: clicked", 1)
	
	if name of theObject is "results" then
		myLog("action: get user details", 1)
		
		show_details_for_selected_result(theObject)
		
	else if name of theObject is "search_adium" then
		myLog("action: user search in adium", 1)
		
		-- Get person ID of the selected row
		set personID to get_selected_person_id(abView)
		if personID is "" then return -- no row selected
		
		-- TODO search by nick also (case no IM number specified in AB)
		
		set theData to get_person_details_from_screen(abView)
		set searchPatterns to compose_adium_search_patterns(theData)
		
		clear_details(adiumView)
		set_adium_status()
		clear_search(adiumView)
		
		start progress indicator "progress" of adiumView
		
		set foundPeople to {}
		repeat with searchPattern in searchPatterns
			set theResults to search_adium_by_id(searchPattern)
			if theResults is not {} then set foundPeople to foundPeople & theResults
		end repeat
		set_status_bar(adiumView, "Searching...")
		populate_table(adiumView, foundPeople)
		set_status_bar(adiumView, "Search AB contact in Adium")
		auto_show_first_result(adiumView)
		
		stop progress indicator "progress" of adiumView
		
	else if name of theObject is "search_ab" then
		myLog("action: user search in ab", 1)
		
		-- Get person ID of the selected row
		set personID to get_selected_person_id(adiumView)
		if personID is "" then return -- no row selected
		
		set {theService, theLogin} to split_service_login(personID)
		myLog("AB search pattern: " & theService & " " & theLogin, 3)
		
		clear_details(abView)
		clear_search(abView)
		
		start progress indicator "progress" of abView
		set_status_bar(abView, "Searching...")
		populate_table(abView, search_ab_by_service(theService, theLogin))
		set_status_bar(abView, "Search Adium contact in AB")
		auto_show_first_result(abView)
		stop progress indicator "progress" of abView
		
		-- If found on AB, disable de ADD button
		if item 1 of get_box_totals(abView) is greater than 0 then
			disable_button("add_to_ab", adiumView)
		end if
		
	else if name of theObject starts with "set_ab_" then
		myLog("action: set AB Info", 1)
		
		set adiumPerson to get_selected_person_id(adiumView)
		set abPerson to get_selected_person_id(abView)
		if abPerson is "" then
			display alert msgSelectPersonToSetAbInfo as warning message msgSelectPersonToSetAbInfoDetails attached to window "main"
		else
			if name of theObject is "set_ab_picture" then
				myLog("action: will set Picture", 2)
				
				copy_adium_picture_to_ab(adiumPerson, abPerson)
				
			else if name of theObject is "set_ab_im" then
				myLog("action: will set IM", 2)
				
				set {theService, theLogin} to split_service_login(adiumPerson)
				set_ab_im(abPerson, theService, theLogin)
			else
				myLog("** Unknown button pressed: " & name of theObject, 1)
			end if
			set_person_details_on_screen(abView, get_ab_person_details(abPerson))
		end if
		
	else if name of theObject is "reveal_ab" then
		myLog("action: Reveal contact in AB", 1)
		
		-- Get person ID of the selected row
		set personID to get_selected_person_id(abView)
		if personID is "" then return -- no row selected
		
		tell application "Address Book"
			set selection to person id personID
			activate
		end tell
		
	else if name of theObject is "add_to_ab" then
		myLog("action: Add contact to AB", 1)
		
		set adiumPerson to get_selected_person_id(adiumView)
		set {theService, theLogin} to split_service_login(adiumPerson)
		
		if search_ab_by_service_test(theService, theLogin) then
			display alert msgPersonAlreadyInAb as warning message msgPersonAlreadyInAbDetails attached to window "main"
			disable_button("add_to_ab", adiumView)
			
		else
			-- Preparing...
			clear_details(abView)
			clear_search(abView)
			start progress indicator "progress" of abView
			set_status_bar(abView, "Adding new contact...")
			
			set theInfo to get_adium_person_details(adiumPerson)
			
			-- Add the new contact to AB (with name), then set IM and picture
			tell application "Address Book"
				set newContact to make new person with properties {first name:|name| of theInfo}
				set abPerson to id of newContact
			end tell
			set_ab_im(abPerson, theService, theLogin)
			copy_adium_picture_to_ab(adiumPerson, abPerson)
			
			-- Contact added. Now fill table with him/her and show the details
			populate_table(abView, {{|id|:abPerson, nick:"", |name|:|name| of theInfo}})
			set_status_bar(abView, "New contact added")
			auto_show_first_result(abView)
			
			stop progress indicator "progress" of abView
			
			-- Finally disable the ADD button
			disable_button("add_to_ab", adiumView)
		end if
	end if
end clicked


-- Search box

on action theObject
	myLog("event: action", 1)
	
	if name of theObject is "search" then
		set theSearchText to content of theObject as text
		
		if (id of theObject) is equal to (id of text field "search" of adiumView) then
			search_adium(theSearchText)
		else
			search_ab(theSearchText)
		end if
	end if
end action


-- Key pressed inside table

on keyboard down theObject event theEvent
	myLog("event: keyboard down", 1)
	
	if key code of theEvent is in {52, 36, 49, 76} then -- ENTER, RETURN, SPACE, ENTER (Fn+return)
		myLog("action: get user details", 1)
		show_details_for_selected_result(theObject)
	end if
end keyboard down


-- Menu item clicked

on choose menu item theObject
	myLog("menu item pressed", 1)
	
	if name of theObject is "report_not_in_ab" then
		set reportName to title of theObject
		myLog("action: report " & reportName, 1)
		
		clear_details(adiumView)
		set_adium_status()
		clear_search(adiumView)
		
		start progress indicator "progress" of adiumView
		set_status_bar(adiumView, "Report: " & reportName)
		populate_table(adiumView, search_report_not_in_ab())
		auto_show_first_result(adiumView)
		stop progress indicator "progress" of adiumView
		
	else if name of theObject is "report_not_in_adium" then
		set reportName to title of theObject
		myLog("action: report " & reportName, 1)
		
		clear_details(abView)
		set_adium_status()
		clear_search(abView)
		
		start progress indicator "progress" of abView
		set_status_bar(abView, "Report: " & reportName)
		populate_table(abView, search_report_not_in_adium())
		auto_show_first_result(abView)
		stop progress indicator "progress" of abView
		
	else if name of theObject is "report_no_im" then
		set reportName to title of theObject
		myLog("action: report " & reportName, 1)
		
		clear_details(abView)
		clear_search(abView)
		
		start progress indicator "progress" of abView
		set_status_bar(abView, "Report: " & reportName)
		populate_table(abView, search_report_ab_no_im())
		auto_show_first_result(abView)
		stop progress indicator "progress" of abView
		
	else if name of theObject is "report_no_picture" then
		set reportName to title of theObject
		myLog("action: report " & reportName, 1)
		
		clear_details(abView)
		clear_search(abView)
		
		start progress indicator "progress" of abView
		set_status_bar(abView, "Report: " & reportName)
		populate_table(abView, search_report_ab_no_picture())
		auto_show_first_result(abView)
		stop progress indicator "progress" of abView
		
	else if name of theObject starts with "report_ab_service_" then
		
		set serviceID to (items -3 thru -1 of (name of theObject as text) as text)
		set reportName to title of theObject
		myLog("action: report " & reportName, 1)
		
		clear_details(abView)
		clear_search(abView)
		
		start progress indicator "progress" of abView
		set_status_bar(abView, "Report: " & reportName)
		populate_table(abView, search_report_ab_with_service(serviceID))
		auto_show_first_result(abView)
		stop progress indicator "progress" of abView
		
	else if name of theObject is "donate" then
		myLog("action: donate", 1)
		
		open location donateUrl
		
	else if name of theObject is "website" then
		myLog("action: website", 1)
		
		open location myUrl
	end if
end choose menu item


-- Sort column
-- Note: code copied verbatim from Apple docs (almost verbatim: s/identifier/name/)

on column clicked theObject table column tableColumn
	myLog("event: column clicked", 1)
	
	set theDataSource to data source of theObject
	set theColumnIdentifier to name of tableColumn
	set theSortColumn to sort column of theDataSource
	-- If clicked column is diff from the current sort column, switch the sort
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
	myLog("event: alert ended", 1)
	-- Nothing to do
end alert ended

-- Quit program if window is closed
on will close theObject
	myLog("event: will close", 1)
	tell me to quit
end will close



(*

XXX - Notes on the Adium install check (disabled)

The Adium install check will only work if I put all the Adium-specific code
into a separate file and use the "load script" command to call it. Then all
its handlers will have to be called within a tell block. 

All the Adium tell blocks (except one) are already inside functions, so the
move won't be that hard. But then I loose the one-file feature and I'm still
not sure if this test is *that* necessary.

So I'm not doing it now. Maybe in future versions.




property msgAdiumNotInstalled : "Sorry, you must have the Adium IM installed on your system to run Adium Book."

on check_adium_install()
	try
		tell application "Finder" to application file id "AdIM"
	on error
		display alert "Adium not installed" as critical message msgAdiumNotInstalled default button "Quit" alternate button "Download Adium" attached to window "main"
	end try
end check_adium_install

-- Alerts

on alert ended theObject with reply theReply
	myLog("event: alert ended", 1)
	
	if button returned of theReply is "Quit" then
		tell me to quit
	else if button returned of theReply is "Download Adium" then
		open location adiumUrl
		tell me to quit
	end if
end alert ended
*)