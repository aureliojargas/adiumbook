-- Adium Book.applescript
-- Adium Book

--  Created by Aurelio Marinho Jargas on Sun Jul 10 2005.
--  License: MIT, Open Source, GPL, whatever. Pick your favorite.
--  More info: http://aurelio.net/bin/as/


-- TODO improved image report (to obsolete my adium script)
-- TODO map Return on table to show user details
-- TODO Find in *: search for name/nick also (only if none found?)
-- TODO new buttons: set IM in AB, add contact to AB
-- TODO only 1 IM field on Adium side, to left space to accomodate new buttons


(* 
						Code Overview

The interface is splitted in two parts (boxes): Adium at left and Address Book
at right. The two properties adiumBox and abBox are shortcuts to refer to
each side. The name of the components are the same on both boxes, so
generic functions can change info on any side, you just have to tell which
box you want.

Before any search, first all the box's info is cleared. The clear_* functions are
used. The search procedure is always the same: clear, start the wheel,
search, populate results table, stop the wheel.

There are three types of search:
- By text: uses the search field and search_*_by_text functions
- Find on the other box: uses "Find in *" buttons and search_*_by_{id, service} functions
- Reports: uses the Reports menu and search_report_* functions

Action events are triggered by:
- Filling search field and hitting Return (to make a text search)
- Clicking on a person on the results table (to get his/her details)
- Clicking on a table heading (to reverse the column sort ordering)
- Clicking buttons (like Find in Adium)
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

Adium must be Online

	You *must* have Adium ON-LINE to use fully this program. If Adium is
	offline it only finds very few contacts with poor details (i.e. no ICQ
	names)

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
			
*)

-- The only property that you may want to change
property theLogLevel : 0 -- Zero: no log, 1: informative log, 2: detailed log, 3: ugly log

-- These are set on "awake from nib"
property adiumBox : ""
property abBox : ""
property adiumPicturesFolder : ""
property abPicturesFolder : ""
property adiumContacts : {0, 0} -- Found / Total
property abContacts : {0, 0}
property adiumOnline : true -- Changing here changes nothing

-- Some random text
property myUrl : "http://aurelio.net/bin/as/adiumbook/"
property adiumUrl : "http://www.adiumx.com"

property tooltipAdiumOffline : "Adium is Offline. Please login or you'll have poor search results."
property tooltipFindInAb : "Try to find this person in Address Book"
property tooltipFindInAdium : "Try to find this person in Adium"
property tooltipSetAbPicture : "Use this picture (on the left) for the Address Book's contact (on the right)"

property msgAdiumNotInstalled : "Sorry, you must have the Adium IM installed on your system to run Adium Book."
property msgSelectPersonToSetAbPicture : "To set somebody's picture, first you need to select the contact on the Address Book view."

----------------------------------------------------------------------------------

on myLog(theMessage, theLevel)
	if theLevel is not greater than theLogLevel then log (theMessage)
end myLog

on check_adium_install()
	try
		tell application "Finder" to application file id "AdIM"
	on error
		display alert "Adium not installed" as critical message msgAdiumNotInstalled default button "Quit" alternate button "Download Adium" attached to window "main"
	end try
end check_adium_install

-- It is a split('".", 1) on Adium person UID
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
	if icq of theData is not "" then set the end of searchPatterns to "ICQ." & icq of theData
	if msn of theData is not "" then set the end of searchPatterns to "MSN." & msn of theData
	if yim of theData is not "" then set the end of searchPatterns to "Yahoo." & yim of theData
	if aim of theData is not "" then
		set the end of searchPatterns to "AIM." & aim of theData
		set the end of searchPatterns to "Mac." & aim of theData
	end if
	myLog(searchPatterns, 3)
	return searchPatterns
end compose_adium_search_patterns

on set_adium_status()
	set currentStatus to adiumOnline
	tell application "Adium"
		if my status of the first Adium controller is offline then
			set adiumOnline to false
		else
			set adiumOnline to true
		end if
	end tell
	if adiumOnline is not currentStatus then
		if not adiumOnline then
			set image of image view "adium icon" of adiumBox to load image "adium-offline"
			set tool tip of image view "adium icon" of adiumBox to tooltipAdiumOffline
		else
			set image of image view "adium icon" of adiumBox to load image "adium"
			delete tool tip of image view "adium icon" of adiumBox
		end if
	end if
	set_total_adium_contacts()
end set_adium_status

on set_status_bar(theBox, theMessage)
	set content of text field "status bar" of theBox to theMessage
end set_status_bar

on set_total_ab_contacts()
	tell application "Address Book" to set total to count (id of every person)
	set item 2 of abContacts to total
end set_total_ab_contacts

on set_total_adium_contacts()
	tell application "Adium" to set total to count (ID of every contact)
	set item 2 of adiumContacts to total
end set_total_adium_contacts

on get_box_total_contacts(theBox)
	if name of theBox as text is "adium" then
		return second item of adiumContacts
	else
		return second item of abContacts
	end if
end get_box_total_contacts

on fmt_contact_count(theCount)
	set {found, total} to theCount
	return (found as text) & " of " & (total as text) & " contacts"
end fmt_contact_count

----------------[ clear ]-------------------

on clear_search(theBox)
	clear_table(theBox)
	set content of text field "search" of theBox to ""
	set_status_bar(theBox, "")
end clear_search

on clear_details(theBox)
	tell theBox
		-- order matters! (on slow computers)
		delete image of image view "picture"
		delete tool tip of image view "picture"
		delete contents of text field "name"
		if (name as text) is "adium" then
			set enabled of button "search_ab" to false
			set enabled of button "set_ab_picture" to false
			delete tool tip of button "search_ab"
			delete tool tip of button "set_ab_picture"
		else
			set enabled of button "search_adium" to false
			delete tool tip of button "search_adium"
		end if
		delete contents of text field "aim"
		delete contents of text field "icq"
		delete contents of text field "msn"
		delete contents of text field "yim"
	end tell
end clear_details

on clear_table(theBox)
	set total to get_box_total_contacts(theBox)
	set_status_bar(theBox, "")
	tell theBox
		delete data rows of data source of table view 1 of scroll view 1
		set content of text field "contacts found" to my fmt_contact_count({0, total})
	end tell
end clear_table

-----------------------------------------------------

on populate_table(theBox, theNewData)
	set total to get_box_total_contacts(theBox)
	tell theBox
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
		set content of text field "contacts found" to my fmt_contact_count({count of theNewData, total})
	end tell
end populate_table


----------------[ search ]-------------------

on search_adium(theSearchText)
	clear_details(adiumBox)
	set_adium_status() -- sets total count, used by clear_table
	clear_table(adiumBox)
	if theSearchText is not "" then
		start progress indicator "progress" of adiumBox
		set_status_bar(adiumBox, "Searching...")
		populate_table(adiumBox, search_adium_by_text(theSearchText))
		set_status_bar(adiumBox, "Search results")
		stop progress indicator "progress" of adiumBox
	end if
end search_adium

on search_ab(theSearchText)
	clear_details(abBox)
	set_total_ab_contacts()
	clear_table(abBox)
	if theSearchText is not "" then
		start progress indicator "progress" of abBox
		set_status_bar(abBox, "Searching...")
		populate_table(abBox, search_ab_by_text(theSearchText))
		set_status_bar(abBox, "Search results")
		stop progress indicator "progress" of abBox
	end if
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
		if theService is in {"AIM", "Mac"} then
			set found to count (every person whose (value of AIM handles) contains theLogin)
		else if theService is "ICQ" then
			set found to count (every person whose (value of ICQ handles) contains theLogin)
		else if theService is "MSN" then
			set found to count (every person whose (value of MSN handles) contains theLogin)
		else if theService is "Yahoo" then
			set found to count of (every person whose (value of Yahoo handles) contains theLogin)
		end if
	end tell
	return found is greater than 0
end search_ab_by_service_test

on search_ab_by_service(theService, theLogin)
	set theResults to {}
	set thePeople to {}
	tell application "Address Book"
		-- There is any contact using this IM id?
		if theService is in {"AIM", "Mac"} then
			set thePeople to (every person whose (value of AIM handles) contains theLogin)
		else if theService is "ICQ" then
			set thePeople to (every person whose (value of ICQ handles) contains theLogin)
		else if theService is "MSN" then
			set thePeople to (every person whose (value of MSN handles) contains theLogin)
		else if theService is "Yahoo" then
			set thePeople to (every person whose (value of Yahoo handles) contains theLogin)
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
		set theResults to {ID, UID, display name} of (every contact whose (UID contains theSearchText) or (display name contains theSearchText))
	end tell
	return convert_results_to_datasource_record(theResults)
end search_adium_by_text

on search_ab_by_text(theSearchText)
	tell application "Address Book"
		set theResults to {id, nickname, name} of (every person whose (nickname contains theSearchText) or (name contains theSearchText))
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
				--my myLog("searching for " & display name, 2)
				if not my search_ab_by_service_test(serviceID, UID) then
					--my myLog("not found", 3)
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
					set userInfo to {aim:"", icq:"", msn:"", yim:""}
					if AIM handles is not {} then set aim of userInfo to (value of first AIM Handle)
					if ICQ handles is not {} then set icq of userInfo to (value of first ICQ handle)
					if MSN handles is not {} then set msn of userInfo to (value of first MSN handle)
					if Yahoo handles is not {} then set yim of userInfo to (value of first Yahoo handle)
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
	
	set theInfo to {|name|:"", nick:"", |picture|:"", aim:"", icq:"", msn:"", yim:""}
	
	tell application "Adium"
		-- XXX Strange, but in Tiger using "(first contact whose" doesn't work 
		repeat with thePerson in (every contact whose ID is thePersonID)
			tell thePerson
				set |name| of theInfo to long display name
				set |picture| of theInfo to adiumPicturesFolder & thePersonID
				if serviceID is in {"AIM", "Mac"} then
					set aim of theInfo to UID
				else if serviceID is "ICQ" then
					set icq of theInfo to UID
				else if serviceID is "MSN" then
					set msn of theInfo to UID
				else if serviceID is "Yahoo" then
					set yim of theInfo to UID
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
	
	set theInfo to {|name|:"", nick:"", |picture|:"", aim:"", icq:"", msn:"", yim:""}
	
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
				try
					set aim of theInfo to (value of first AIM Handle)
				end try
				try
					set icq of theInfo to (value of first ICQ handle)
				end try
				try
					set msn of theInfo to (value of first MSN handle)
				end try
				try
					set yim of theInfo to (value of first Yahoo handle)
				end try
			end tell
			exit repeat
		end repeat
	end tell
	return theInfo
end get_ab_person_details


-- Format and show up person info (name, picture, etc) on the screen

on set_person_details_on_screen(theBox, theInfo)
	
	-- Append quoted nick after name (if any)
	if nick of theInfo is not "" and nick of theInfo is not missing value then
		set |name| of theInfo to |name| of theInfo & return & "\"" & nick of theInfo & "\""
	end if
	
	-- Update screen
	tell theBox
		-- Documentation said we must always del the references manually
		delete image of image view "picture"
		delete tool tip of image view "picture"
		try
			set image of image view "picture" to load image |picture| of theInfo
			set tool tip of image view "picture" to |picture| of theInfo
		end try
		
		-- Order matters (on slow computers)
		set content of text field "name" to |name| of theInfo
		if (name as text) is "adium" then
			-- On/Off for the "set picture" button
			if (exists image of image view "picture") then
				set enabled of button "set_ab_picture" to true
				set tool tip of button "set_ab_picture" to tooltipSetAbPicture
			else
				set enabled of button "set_ab_picture" to false
				delete tool tip of button "set_ab_picture"
			end if
			
			set enabled of button "search_ab" to true
			set tool tip of button "search_ab" to tooltipFindInAb
		else
			set enabled of button "search_adium" to true
			set tool tip of button "search_adium" to tooltipFindInAdium
		end if
		set content of text field "aim" to aim of theInfo
		set content of text field "icq" to icq of theInfo
		set content of text field "msn" to msn of theInfo
		set content of text field "yim" to yim of theInfo
	end tell
end set_person_details_on_screen

on get_person_details_from_screen(theBox)
	
	set theInfo to {|name|:"", nick:"", |picture|:"", aim:"", icq:"", msn:"", yim:""}
	
	set aim of theInfo to content of text field "aim" of theBox
	set icq of theInfo to content of text field "icq" of theBox
	set msn of theInfo to content of text field "msn" of theBox
	set yim of theInfo to content of text field "yim" of theBox
	return theInfo
	
	--set |name| of theInfo to content of text field "name" of theBox
	--set |picture| of theInfo to image of image view "picture" of theBox
	-- XXX put nick on a separate box?	
end get_person_details_from_screen

on get_selected_person_id(theBox)
	try
		set theRow to selected data row of table view 1 of scroll view 1 of theBox
		return contents of data cell "id" of theRow
	on error
		return ""
	end try
end get_selected_person_id

---------------------------------------------------------------------------------------

-- Init process: set global properties and create/link the data sources

on awake from nib theObject
	myLog("event: awake from nib", 1)
	
	-- Setting here works fine. Setting on property definition gets MY home path hardcoded...
	set adiumPicturesFolder to POSIX path of (path to library folder from user domain) & "Caches/Adium/Default/"
	set abPicturesFolder to POSIX path of (path to application support from user domain) & "AddressBook/Images/"
	
	-- Adium MUST be installed
	check_adium_install()
	
	-- Handy shortcuts for each half of the screen
	set adiumBox to box "adium" of window "main"
	set abBox to box "ab" of window "main"
	
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
	set data source of table view 1 of scroll view 1 of adiumBox to adiumDataSource
	set data source of table view 1 of scroll view 1 of abBox to abDataSource
	myLog("init: data sources linked to table views", 2)
	
	-- set total count & adium status
	set_total_ab_contacts()
	set_adium_status()
	myLog("init: contacts count & Adium status OK", 2)
	
	-- Initialize tables
	clear_table(adiumBox)
	clear_table(abBox)
	myLog("init: done", 2)
	
end awake from nib


-- Button or table clicked

on clicked theObject
	myLog("event: clicked", 1)
	
	if name of theObject is "results" then
		myLog("action: get user details", 1)
		
		-- Get person ID of the clicked row
		set rowIndex to clicked row of theObject
		if rowIndex is 0 then return -- zero is header
		set theRow to clicked data row of theObject
		set personID to contents of data cell "id" of theRow
		
		-- Get info for the selected person and show on screen
		if (id of theObject) is equal to (id of table view 1 of scroll view 1 of adiumBox) then
			myLog("action: will get details in Adium", 1)
			set personInfo to get_adium_person_details(personID)
			set_person_details_on_screen(adiumBox, personInfo)
		else
			myLog("action: will get details in Address Book", 1)
			set personInfo to get_ab_person_details(personID)
			set_person_details_on_screen(abBox, personInfo)
		end if
		
	else if name of theObject is "search_adium" then
		myLog("action: user search in adium", 1)
		
		-- Get person ID of the selected row
		set personID to get_selected_person_id(abBox)
		if personID is "" then return -- no row selected
		
		-- TODO search by nick also (case no IM number specified in AB)
		
		set theData to get_person_details_from_screen(abBox)
		set searchPatterns to compose_adium_search_patterns(theData)
		
		clear_details(adiumBox)
		set_adium_status()
		clear_search(adiumBox)
		
		start progress indicator "progress" of adiumBox
		
		set foundPeople to {}
		repeat with searchPattern in searchPatterns
			set theResults to search_adium_by_id(searchPattern)
			if theResults is not {} then set foundPeople to foundPeople & theResults
		end repeat
		set_status_bar(adiumBox, "Searching...")
		populate_table(adiumBox, foundPeople)
		set_status_bar(adiumBox, "Search AB contact in Adium")
		
		stop progress indicator "progress" of adiumBox
		
	else if name of theObject is "search_ab" then
		myLog("action: user search in ab", 1)
		
		-- Get person ID of the selected row
		set personID to get_selected_person_id(adiumBox)
		if personID is "" then return -- no row selected
		
		set {theService, theLogin} to split_service_login(personID)
		myLog("AB search pattern: " & theService & " " & theLogin, 3)
		
		clear_details(abBox)
		clear_search(abBox)
		set_total_ab_contacts()
		
		start progress indicator "progress" of abBox
		set_status_bar(abBox, "Searching...")
		populate_table(abBox, search_ab_by_service(theService, theLogin))
		set_status_bar(abBox, "Search Adium contact in AB")
		stop progress indicator "progress" of abBox
		
	else if name of theObject is "set_ab_picture" then
		myLog("action: set AB picture", 1)
		set adiumPerson to get_selected_person_id(adiumBox)
		set abPerson to get_selected_person_id(abBox)
		if abPerson is "" then
			display alert "Oops!" as warning message msgSelectPersonToSetAbPicture attached to window "main"
		else
			tell application "Adium" to set thePicture to image of first contact whose ID is adiumPerson
			tell application "Address Book" to set image of first person whose id is abPerson to thePicture
			set_person_details_on_screen(abBox, get_ab_person_details(abPerson))
		end if
	end if
end clicked


-- Search box

on action theObject
	myLog("event: action", 1)
	
	if name of theObject is "search" then
		set theSearchText to content of theObject as text
		
		if (id of theObject) is equal to (id of text field "search" of adiumBox) then
			search_adium(theSearchText)
		else
			search_ab(theSearchText)
		end if
	end if
end action


-- Menu item clicked

on choose menu item theObject
	myLog("menu item pressed", 1)
	
	if name of theObject is "report_not_in_ab" then
		myLog("action: report not in ab", 1)
		
		clear_details(adiumBox)
		set_adium_status()
		clear_search(adiumBox)
		
		start progress indicator "progress" of adiumBox
		set_status_bar(adiumBox, "Report: Adium contacts not in AB")
		populate_table(adiumBox, search_report_not_in_ab())
		stop progress indicator "progress" of adiumBox
		
	else if name of theObject is "report_not_in_adium" then
		myLog("action: report not in adium", 1)
		
		clear_details(abBox)
		set_adium_status()
		clear_search(abBox)
		
		start progress indicator "progress" of abBox
		set_status_bar(abBox, "Report: AB contacts not in Adium")
		populate_table(abBox, search_report_not_in_adium())
		stop progress indicator "progress" of abBox
		
	else if name of theObject is "report_no_im" then
		myLog("action: report no IM", 1)
		
		clear_details(abBox)
		clear_search(abBox)
		
		start progress indicator "progress" of abBox
		set_status_bar(abBox, "Report: AB contacts with no IM")
		populate_table(abBox, search_report_ab_no_im())
		stop progress indicator "progress" of abBox
		
	else if name of theObject is "report_no_picture" then
		myLog("action: report no picture", 1)
		
		clear_details(abBox)
		clear_search(abBox)
		
		start progress indicator "progress" of abBox
		set_status_bar(abBox, "Report: AB contacts with no picture")
		populate_table(abBox, search_report_ab_no_picture())
		stop progress indicator "progress" of abBox
		
		(* TODO		
	else if name of theObject is "report_picture_copy" then
		myLog("action: report picture copy", 1)
		
		clear_details(adiumBox)
		clear_search(adiumBox)
		
		start progress indicator "progress" of adiumBox
		set_status_bar(adiumBox, "Report: Adium > AB Picture Copy")
		--populate_table(abBox, search_report_ab_no_picture())
		populate_table(abBox, {})
		stop progress indicator "progress" of adiumBox
*)
	else if name of theObject starts with "report_ab_service_" then
		
		if name of theObject ends with "aim" then
			set {serviceID, serviceName} to {"aim", "AIM/.Mac"}
		else if name of theObject ends with "icq" then
			set {serviceID, serviceName} to {"icq", "ICQ"}
		else if name of theObject ends with "msn" then
			set {serviceID, serviceName} to {"msn", "MSN"}
		else if name of theObject ends with "yim" then
			set {serviceID, serviceName} to {"yim", "Yahoo!"}
		end if
		myLog("action: report with " & serviceName, 1)
		
		clear_details(abBox)
		clear_search(abBox)
		
		start progress indicator "progress" of abBox
		set_status_bar(abBox, "Report: AB contacts with " & serviceName)
		populate_table(abBox, search_report_ab_with_service(serviceID))
		stop progress indicator "progress" of abBox
		
	else if name of theObject is "website" then
		myLog("action: website", 1)
		
		open location myUrl
	end if
end choose menu item


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
