#include <windows.h>
#include <stdio.h>


// uses inpout32.dll and its inpout32.lib

short _stdcall Inp32(short PortAddress);
void _stdcall Out32(short PortAddress, short data);
extern "C"{
BOOL WINAPI SwitchToThread(VOID);
}






void sendByte(char x){
	short y = x;
	y &=255;
	Out32(0x378,y);
	Out32(0x37A,1);
	Out32(0x37A,0);
	for(int i=0;i<100;i++)Out32(0x378,y);
}




POINT LStick={128,128};
POINT MOUSE={0,0};
char digits1=0,digits2=0;




bool SendData(){
	sendByte(digits1);
	sendByte(digits2);
	sendByte((char)LStick.x);
	sendByte((char)LStick.y);
	sendByte((char)(MOUSE.x>>0));
	sendByte((char)(MOUSE.x>>8));
	sendByte((char)(MOUSE.y>>0));
	sendByte((char)(MOUSE.y>>8));
	return true;
}






WPARAM MAP[16]={'A','S','D','F','G','H','J','K',   '1','2','3','4','5','6','7','8'};


int Sensitivity=10;


int UpdateKeys(){
	char prev1 = digits1;
	char prev2 = digits2;

	int i;
	char flag;
	for(i=0;i<8;i++){
		flag=1<<i;
		digits1 &= ~flag;
		if(0x8000 & GetAsyncKeyState(MAP[i]))digits1 |=flag;
	}
	for(i=0;i<8;i++){
		flag=1<<i;
		digits2 &= ~flag;
		if(0x8000 & GetAsyncKeyState(MAP[i+8]))digits2 |=flag;
	}
	if(prev1==digits1 && prev2==digits2)return 0;
	return 1;
}



BOOL CALLBACK DialogProc(HWND hWnd,UINT msg,WPARAM w,LPARAM l){
	
	static int yoshi=0;
	static POINT prevmouse;
	if(msg==WM_CLOSE){
		EndDialog(hWnd,0);
	}else if(/*msg==WM_MOUSEMOVE || */msg==WM_TIMER){
		POINT curmouse;
		GetCursorPos(&curmouse);
		MOUSE.x = (curmouse.x-prevmouse.x)*Sensitivity;
		MOUSE.y = (curmouse.y-prevmouse.y)*Sensitivity;
		prevmouse.x = curmouse.x;
		prevmouse.y = curmouse.y;
		int nkeys = UpdateKeys();

		if(MOUSE.x!=0 || MOUSE.y!=0 || nkeys){
			SendData();
			//SetDlgItemInt(hWnd,101,++yoshi,0);
			SetCursorPos(500,500);
			prevmouse.x=500;
			prevmouse.y=500;
		}
#define WM_MOUSEWHEEL 			0x20A
	}else if(msg==WM_MOUSEWHEEL){
		w>>=31;w&=1;
		if(w)Sensitivity--; else Sensitivity++;
		if(Sensitivity<1)Sensitivity=1;
		if(Sensitivity>50)Sensitivity=50;
		SetDlgItemInt(hWnd,101,Sensitivity,0);
	}else if(msg==WM_INITDIALOG){
		GetCursorPos(&prevmouse);
		SetTimer(hWnd,1,20,0);
	}else{
		return false;
	}
	return true;
}

// 3.170us for 1 million sends

int APIENTRY WinMain(HINSTANCE hInstance,HINSTANCE hPrevInstance,LPSTR lpCmdLine,int nCmdShow){
	Out32(0x378,0);
	Out32(0x37A,0);
	MessageBox(0,"Press OK to start","PSX commander",0);

	DialogBox(hInstance,(LPCSTR)100,0,DialogProc);
		
	Out32(0x378,0);
	Out32(0x37A,0);
	return 0;
}



