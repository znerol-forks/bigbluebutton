package org.bigbluebutton.modules.breakout.business
{
	import com.adobe.crypto.SHA1;
	
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.events.SyncEvent;
	import flash.net.NetConnection;
	import flash.net.SharedObject;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.navigateToURL;
	
	import mx.controls.Alert;
	import mx.events.CloseEvent;

	public class BreakoutProxy
	{		
		private var urlLoader:URLLoader;
		private var request:URLRequest;
		private var meetingName:String;
		private var attendeePW:String;
		private var moderatorPW:String;
		
		private var host:String;
		private var conference:String;
		private var room:String;
		private var userid:Number;
		private var username:String;
		private var userrole:String;
		private var connection:NetConnection;
		private var ncURL:String;
		private var breakoutSO:SharedObject;
		
		private var usersList:Array;
		private var kickUsers:Boolean;
		
		private var api_url:String;
		private var api_salt:String;
		
		private var completeJoinUrl:String;
		private var newWindow:String;
		
		public function BreakoutProxy()
		{
			urlLoader = new URLLoader();
		}
		
		public function connect(a:Object):void{
			host = a.host as String;
			conference = a.conference as String;
			room = a.room as String;
			userid = a.userid as Number;
			username = a.username as String;
			userrole = a.userrole as String;
			connection = a.connection;
			ncURL = connection.uri;
			
			api_url = host + "/bigbluebutton/api";
			api_salt = a.salt;
			
			breakoutSO = SharedObject.getRemote("breakoutSO", ncURL, false);
			breakoutSO.addEventListener(SyncEvent.SYNC, sharedObjectSyncHandler);
			breakoutSO.addEventListener(NetStatusEvent.NET_STATUS, netStatusEventHandler);
			breakoutSO.client = this;
			breakoutSO.connect(connection);
		}
		
		private function sharedObjectSyncHandler(e:SyncEvent):void{
			
		}
		
		private function netStatusEventHandler(e:NetStatusEvent):void{
			
		}
		
		public function createRoom(usersList:Array, kickUsers:Boolean):void{
			this.usersList = usersList;
			this.kickUsers = kickUsers;
			
			meetingName = Math.random().toString();
			var createString:String = "create" + "name=" + meetingName + "&meetingID=" + meetingName + api_salt;
			var hash:String = SHA1.hash(createString);
			
			var completeUrl:String = api_url + "/create?" + "name=" + meetingName + "&meetingID=" + meetingName + "&checksum=" + hash;
			request = new URLRequest(completeUrl);
			request.method = URLRequestMethod.GET;
			urlLoader.addEventListener(Event.COMPLETE, handleMeetingCreated);
			urlLoader.load(request);
		}
		
		private function handleMeetingCreated(e:Event):void{
			//Alert.show("" + e.target.data);
			//var returnString:String = '<?xml version="1.0" ?>' + e.target.data;
			var xml:XML = new XML(e.target.data);
			
			if (xml.returncode == "SUCCESS"){
				attendeePW = xml.attendeePW;
				moderatorPW = xml.moderatorPW;
				startRoom();
			} else if (xml.returncode == "FAILED"){
				Alert.show(xml.messageKey + ":" + xml.message);
			}
			urlLoader.removeEventListener(Event.COMPLETE, handleMeetingCreated);
		}
		
		private function startRoom():void{
			breakoutSO.send("redirectUser", meetingName, moderatorPW, attendeePW, kickUsers, usersList);
		}
		
		public function redirectUser(newMeetingName:String, newModeratorPW:String, newAttendeePW:String, kickUser:Boolean, userList:Array):void{
			if (!checkIfUserInList(userList)) return;
			
			var password:String;
			if (userrole == "MODERATOR" ) password = newModeratorPW;
			else password = newAttendeePW;
			
			var safeUsername:String = username.replace(" ", "+");
			
			var joinString:String = "join" + "fullName=" + safeUsername + "&meetingID=" + newMeetingName + "&password=" + password + "&userID=" + userid + api_salt;
			var hash:String = SHA1.hash(joinString);
			
			completeJoinUrl = api_url + "/join?" + "fullName=" + safeUsername + "&meetingID=" + newMeetingName + 
										"&password=" + password + "&userID=" + userid + "&checksum=" + hash;
			
			var logoutMessage:String;
			if (kickUser){
				newWindow = "_self";
				logoutMessage = "You are being redirected to a new meeting. Click to continue";
			} 
			else if (!kickUser){
				newWindow = "_blank";
				logoutMessage = "A new meeting will open. Click to continue";
			} 
			
			//Alert.show(completeJoinUrl);
			
			Alert.show(logoutMessage, "", 4, null, onAlertClose);
		}
		
		private function onAlertClose(e:CloseEvent):void{
			request = new URLRequest(completeJoinUrl);
			navigateToURL(request, newWindow);
		}
		
		private function checkIfUserInList(list:Array):Boolean{
			for (var i:int = 0; i<list.length; i++){
				if (list[i] == userid) return true;
			}
			return false;
		}
	}
}