/* Copyright 2024 Lorenzo Lunelli

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License. */

requires ("1.52u"); // Math functions, additional Roi manager functions
// ================== default values ============================
fixedbase=0;  // default level of fixed background (for volume computation)
localback=false; // switch for using a locally computed background
negheights=false; // switch for allowing heights below the reference surface
cleartable=false;// switch for clearing tables at beginning
restoreROI=false;// switch for reloading the previous ROIs 
mindiam=35.7;
maxdiam=10000;
mincirc=0.3;
minpix=true; // consider only particles at least 4 pixels area
exclude=true; // switch for excluding particles on edges
idbil=false; // try to identify bilayers
bilmin=4;
bilmax=6;
bilstd=1;
Npoints=5; // number of highest point for statistics evaluation
Tableitems=newArray("do not clear","clear","clear&save","clear&save&save image");
tableaction="clear&save&save image";
backlevelitems=newArray("use the fixed background level","compute local background for every particle");
if (localback) {
	backlevelitem=backlevelitems[1];
} else {
	backlevelitem=backlevelitems[0];
}

sh=screenHeight;
sw=screenWidth;

windowList=getList("image.titles");
if (windowList.length==0) {
	exit("No image open!");
}

Dialog.create("EVs radius evaluation");
Dialog.setInsets(0,0,0);
Dialog.addMessage("Parameters for particle identification", 14, "blue");
Dialog.addNumber("min projected diameter", mindiam, 1, 6, "nm");
Dialog.addNumber("max projected diameter", maxdiam, 1, 6, "nm");
Dialog.addNumber("min circularity", mincirc, 2, 6, "");
Dialog.addCheckbox("only use particles with area>=4 pixels", minpix);
Dialog.addCheckbox("exclude particles on edges", exclude);
Dialog.addMessage("---------------------------"®, 14, "blue");
Dialog.addCheckbox("identify bilayers", idbil);
Dialog.addNumber("min. bilayer height", bilmin, 1, 6, "nm");
Dialog.addNumber("max. bilayer height", bilmax, 1, 6, "nm");
Dialog.addNumber("max. height std", bilstd, 1, 6, "nm");

Dialog.setInsets(20,0,0);
Dialog.addMessage("Parameters for Top height computation", 14, "blue");
Dialog.setInsets(10,0,0);
Dialog.addNumber("number of top height points", Npoints, 0, 4, "");

Dialog.setInsets(20,0,0);
Dialog.addMessage("Parameters for height and volume computation", 14, "blue");
Dialog.setInsets(10,0,0);
Dialog.addNumber("fixed background level", fixedbase, 1, 6, "nm");
Dialog.addToSameRow();
Dialog.addCheckbox("allow negative heights (holes)", negheights);
Dialog.addRadioButtonGroup("background level", backlevelitems, 2, 1, backlevelitem);

Dialog.setInsets(20,0,0);
Dialog.addMessage("Misc options", 14, "blue");
Dialog.addRadioButtonGroup("Tables", Tableitems, 2, 2, tableaction);
Dialog.addCheckbox("restore ROI manager", restoreROI);

Dialog.show();

// ===================== get user inputs ===============================
mindiam=Dialog.getNumber();
maxdiam=Dialog.getNumber();
mincirc=Dialog.getNumber();
minpix=Dialog.getCheckbox();
exclude=Dialog.getCheckbox();
idbil=Dialog.getCheckbox();
bilmin=Dialog.getNumber();
bilmax=Dialog.getNumber();
bilstd=Dialog.getNumber();

Npoints=Math.floor(Dialog.getNumber());

fixedbase=Dialog.getNumber();
negheights=Dialog.getCheckbox();
typeback=Dialog.getRadioButton();
if (typeback==backlevelitems[1]) {
	localback=true;
} else  {
	localback=false;
}

tableaction=Dialog.getRadioButton();
if (tableaction=="clear") {
	cleartable=true;
	savetables=false;
	saveimage=false;
} else if (tableaction=="clear&save") {
	cleartable=true;
	savetables=true;
	saveimage=false;
} else if (tableaction=="clear&save&save image") {
	cleartable=true;
	savetables=true;
	saveimage=true;
} else {
	cleartable=false;
	savetables=false;
	saveimage=false;
}
restoreROI=Dialog.getCheckbox();
// ======================================================================

minarea=PI*Math.sqr(mindiam/2);
maxarea=PI*Math.sqr(maxdiam/2);
getPixelSize(unit, pixelWidth, pixelHeight);
if (unit=="nm") {
	areaconversion=pixelWidth*pixelHeight;
	xlengthconversion=pixelWidth;
	ylengthconversion=pixelHeight;
} else if (unit==getInfo("micrometer.abbreviation")) {
	areaconversion=pixelWidth*pixelHeight*1.0e6;
	xlengthconversion=pixelWidth*1.0e3;
	ylengthconversion=pixelHeight*1.0e3;
} else {
	exit("unknown units!");
}

fourpixelsarea=4*areaconversion;
if (fourpixelsarea>minarea && minpix) {
	minarea=fourpixelsarea;
}

myTable="EVs_analysis";
if (cleartable || !isOpen(myTable)) {
	Table.create(myTable);
}
Table.setLocationAndSize(sw*0.2, sh*0.1+430, 800, 300);

ROIfilepath=getDir("temp")+File.separator +"EVsTempROI.zip";
numberbeforeROIs=roiManager("size");
if (numberbeforeROIs>0 && restoreROI) {
	roiManager("save", ROIfilepath);
}
roiManager("reset");
id=getImageID();
imagename=getInfo("image.title");
imagedir=getInfo("image.directory");

// ==================================================================================================
run("Select None");
run("Threshold...");
getThreshold(lowT,uppT);
if (exclude) {
	run("Analyze Particles...", "size=&minarea-&maxarea circularity=&mincirc-1.00 exclude add");
} else {
	run("Analyze Particles...", "size=&minarea-&maxarea circularity=&mincirc-1.00 add");	
}
// ==================================================================================================

// ============= parameters Table ==================
paramTable="Parameters for EVs analysis";
Table.create(paramTable);
Table.setLocationAndSize(sw*0.2, sh*0.1, 600, 430);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "Image name",paramTable);
Table.set("value", rowIndex, imagename,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "lower Threshold",paramTable);
Table.set("value", rowIndex, lowT,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "upper Threshold",paramTable);
Table.set("value", rowIndex, uppT,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "min. diam.",paramTable);
Table.set("value", rowIndex, mindiam,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "max. diam",paramTable);
Table.set("value", rowIndex, maxdiam,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "min. circ.",paramTable);
Table.set("value", rowIndex, mincirc,paramTable);
rowIndex=Table.size(paramTable);
if (minpix) {
	Table.set("parameter", rowIndex, ">=4 pixels area: YES",paramTable);
	Table.set("value", rowIndex, fourpixelsarea,paramTable);
} else {
	Table.set("parameter", rowIndex, ">4 pixels area: NO",paramTable);
	Table.set("value", rowIndex, "-",paramTable);
}
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "exclude particles on edges:",paramTable);
if (exclude) {
	Table.set("value", rowIndex, "YES",paramTable);
} else {
	Table.set("value", rowIndex, "NO",paramTable);	
}
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "min. bilayer height",paramTable);
if (idbil) {Table.set("value", rowIndex, bilmin,paramTable);} else {Table.set("value", rowIndex, "-",paramTable);};
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "max. bilayer height",paramTable);
if (idbil) {Table.set("value", rowIndex, bilmax,paramTable);} else {Table.set("value", rowIndex, "-",paramTable);};
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "bilayer height std",paramTable);
if (idbil) {Table.set("value", rowIndex, bilstd,paramTable);} else {Table.set("value", rowIndex, "-",paramTable);};
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "number of top points",paramTable);
Table.set("value", rowIndex, Npoints,paramTable);
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "base level",paramTable);
if (localback) {
	Table.set("value", rowIndex, "local",paramTable);
} else  {
	Table.set("value", rowIndex,"fixed="+fixedbase,paramTable);
}
rowIndex=Table.size(paramTable);
Table.set("parameter", rowIndex, "allow negative heights (holes)",paramTable);
if (negheights) {
	Table.set("value", rowIndex, "YES",paramTable);
} else  {
	Table.set("value", rowIndex,"NO",paramTable);
}
Table.update;
// =================================================

numROIs=RoiManager.size;
for (index=0;index<numROIs;index++) {
	rowIndex=Table.size(myTable);
	RoiManager.select(index);
	Roi.getContainedPoints(xpoints, ypoints);
	numb_allpoints=xpoints.length;
	getSelectionBounds(xs, ys, widths, heights);
	base_area=baseArea(numb_allpoints,areaconversion);
	triang_area=triangArea(xs, ys, widths, heights,xlengthconversion,ylengthconversion,fixedbase,localback,negheights);
	surf_total=base_area+triang_area;
	triang_volume=triangVolume(xs, ys, widths, heights,xlengthconversion,ylengthconversion,fixedbase,localback,negheights);
	volume=Volume(xs, ys, widths, heights,areaconversion,fixedbase,localback,negheights);
	N_topstats=topNpoints(xs, ys, widths, heights,xpoints, ypoints,Npoints,fixedbase,localback,negheights);
	allstats=topNpoints(xs, ys, widths, heights,xpoints, ypoints,numb_allpoints,fixedbase,localback,negheights);
	mean=allstats[0]; std=allstats[1];
	surfRadius=Math.sqrt(surf_total/(4*PI));
	triangvolRadius=Math.pow(triang_volume*3/(4*PI),1/3);
	volRadius=Math.pow(volume*3/(4*PI),1/3);
	Table.set("index", rowIndex, index+1,myTable);
	Table.set("label", rowIndex, imagename,myTable);
	Table.set("radius from surf. (nm)", rowIndex, surfRadius,myTable);
	Table.set("radius from triang. vol. (nm)", rowIndex, triangvolRadius,myTable);
	Table.set("radius from volume (nm)", rowIndex, volRadius,myTable);	
	Table.set("Base Surface", rowIndex, base_area,myTable);
	Table.set("Total Surface", rowIndex, surf_total,myTable);
	Table.set("Triang. Volume", rowIndex, triang_volume,myTable);
	Table.set("Volume", rowIndex, volume,myTable);
	Table.set("mean height", rowIndex, mean,myTable);
	Table.set("standard deviation", rowIndex, std,myTable);
	Table.set("Top N points mean height", rowIndex, N_topstats[0],myTable);
	Table.set("Top N points std. dev.", rowIndex, N_topstats[1],myTable);	
	if (idbil && mean>=bilmin && mean<=bilmax && std<=bilstd) {
		Table.set("type", rowIndex, "bilayer",myTable);
	} else {
		Table.set("type", rowIndex, "particle",myTable);
	}
}
Table.update(myTable);

// get date and time of analysis
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
if (savetables) {
	datetime4table=toString(year)+"-"+toString(month+1)+"-"+toString(dayOfMonth)+"_"+toString(hour)+"."+toString(minute)+"."+toString(second);
	date="_"+datetime4table;
	if (imagedir=="") {
		imagedir=getDir("Choose a Directory");
	}
	Table.save(imagedir+imagename+date+"_"+myTable+".csv",myTable);
	Table.save(imagedir+imagename+date+"_"+myTable+"_parameters.csv",paramTable);
	showMessage("Tables saved.");
}

if (saveimage) {
	roiManager("show all with labels");
	datetime4table=toString(year)+"-"+toString(month+1)+"-"+toString(dayOfMonth)+"_"+toString(hour)+"."+toString(minute)+"."+toString(second);
	date="_"+datetime4table;
	if (imagedir=="") {
		imagedir=getDir("Choose a Directory");
	}
	saveAs("tiff", imagedir+imagename+date+"_particles.tif");
	rename(imagename);
	showMessage("Image saved.");
}

if (numberbeforeROIs>0 && restoreROI) {
	roiManager("reset");
	roiManager("open", ROIfilepath);
}

// ====================== functions below ================================
function topNpoints(xs, ys, widths, heights,xpoints, ypoints,N,base,localback,negh) {
	if (localback) {
		base=LocalBase(xs, ys, widths, heights);
	}
	ll=xpoints.length;
	heights=newArray();
	for (index=0;index<ll;index++) {
		heights[index]=MygetPixel(xpoints[index], ypoints[index],base,negh);
	}
	Array.sort(heights);
	Array.reverse(heights);
	Ntoppoints=Array.trim(heights, N);
	//Array.show(Ntoppoints);
	Array.getStatistics(Ntoppoints, min, max, mean, StDev);
	retValue=newArray(2);
	retValue[0]=mean; retValue[1]=StDev;
	return retValue;
}


function baseArea(ll,areaconversion) {
	result=ll*areaconversion;
	//print("base Area elements",ll);
	return result;
}


function triangVolume(xs, ys, widths, heights,pw,ph,base,localback,negh) { // everything is assumed to be in nm here
	if (localback) {
		base=LocalBase(xs, ys, widths, heights);
	}
	result=0;
	numelements=0;
	for (xi=xs;xi<xs+widths;xi++) {
		for (yi=ys;yi<ys+heights;yi++) {
			Z1=MygetPixel(xi, yi,base,negh); // P1
			Z2=MygetPixel(xi+1, yi,base,negh); // P2
			Z3=MygetPixel(xi, yi+1,base,negh); //P3
			Z4=MygetPixel(xi+1, yi+1,base,negh); // P4
			//print("Z1,Z2,Z3,Z4",Z1,Z2,Z3,Z4);
			//print("xi,yi",xi,yi);
			if (Roi.contains(xi, yi) || Roi.contains(xi+1, yi) || Roi.contains(xi, yi+1) || Roi.contains(xi+1, yi+1)) {
				// =================== first volume ==== (points P1,P2,P3)
				zz=newArray(Z1,Z2,Z3);
				ranks=Array.rankPositions(zz);
				apexpoint=zz[ranks[0]]; // z coordinate of the point that has the smallest z height
				P1=newArray(xi,yi,Z1-apexpoint);
				P2=newArray(xi+1,yi,Z2-apexpoint);
				P3=newArray(xi+1,yi+1,Z3-apexpoint);
				volPrism1=pw*ph*Math.abs(apexpoint)/2;
				if (P1[2]==0) {           // case a) apex point is P1
					a=P2[0]-P1[0];
					b=P3[1]-P1[1];
					c=Math.sqrt(Math.sqr(a)+Math.sqr(b));
					basePyr=(P2[2]+P3[2])*c/2;
					hPyr=a*b/c;
				} else 	if (P2[2]==0) {   // case b) apex point is P2
					basePyr=(P1[2]+P3[2])*(P3[1]-P1[1])/2;
					hPyr=P2[0]-P1[0];
				} else if (P3[2]==0) {    // case 3) apex point is P3
					basePyr=(P1[2]+P2[2])*(P2[0]-P1[0])/2;
					hPyr=P3[1]-P1[1];
				}
				volPyr1=basePyr*hPyr/3;
				// ==================== second volume ==== (points P4,P3,P2)
				zz=newArray(Z4,Z3,Z2);
				ranks=Array.rankPositions(zz);
				apexpoint=zz[ranks[0]]; // z coordinate of the point that has the smallest z height
				P4=newArray(xi+1,yi+1,Z4-apexpoint);
				P3=newArray(xi,yi+1,Z3-apexpoint);
				P2=newArray(xi+1,yi,Z2-apexpoint);
				volPrism2=pw*ph*Math.abs(apexpoint)/2;
				if (P4[2]==0) {          // case a) apex point is P4
					a=P4[0]-P3[0];
					b=P4[1]-P2[1];
					c=Math.sqrt(Math.sqr(a)+Math.sqr(b));
					basePyr=(P2[2]+P3[2])*c/2;
					hPyr=a*b/c;
				} else if (P2[2]==0) {   // case b) apex point is P2
					basePyr=(P4[2]+P3[2])*(P4[0]-P3[0])/2;
					hPyr=P4[1]-P2[1];
				} else if (P3[2]==0) {   // case 3) apex point is P3
					basePyr=(P4[2]+P2[2])*(P4[1]-P2[1])/2;
					hPyr=P4[0]-P3[0];
				}
				volPyr2=basePyr*hPyr/3;
				result=result+volPrism1+volPrism2+volPyr1+volPyr2;
				numelements++;
			}
		}
	}
	return result;
}


function triangArea(xs, ys, widths, heights,pw,ph,base,localback,negh) {
	if (localback) {
		base=LocalBase(xs, ys, widths, heights);
	}
	result=0;
	numelements=0;
	for (xi=xs;xi<xs+widths;xi++) {
		for (yi=ys;yi<ys+heights;yi++) {
		
			Z1=MygetPixel(xi, yi,base,negh); // P1
			Z2=MygetPixel(xi+1, yi,base,negh); // P2
			Z3=MygetPixel(xi, yi+1,base,negh); //P3
			Z4=MygetPixel(xi+1, yi+1,base,negh); // P4
			//Z1=getPixel(xi, yi);
			//Z2=getPixel(xi+1, yi);
			//Z3=getPixel(xi, yi+1);
			//Z4=getPixel(xi+1, yi+1);
			if (Roi.contains(xi, yi) || Roi.contains(xi+1, yi) || Roi.contains(xi, yi+1) || Roi.contains(xi+1, yi+1)) { 
				u1Len=Math.sqrt(Math.sqr(-ph*(Z2-Z1))+Math.sqr(pw*(Z3-Z1))+Math.sqr(pw*ph));
				u2Len=Math.sqrt(Math.sqr(ph*(Z3-Z4))+Math.sqr(-pw*(Z2-Z4))+Math.sqr(pw*ph));
				result=result+0.5*(u1Len+u2Len);
				numelements++;
			}	
		}
	}
//	print("Area elements",numelements);
	return result;
}


function Volume(xs, ys, widths, heights,areaconversion,base,localback,negh) { // everything is assumed to be in nm here
	if (localback) {
		base=LocalBase(xs, ys, widths, heights);
	}
	Roi.getContainedPoints(xpoints, ypoints);
	ll=xpoints.length;
	result=0;
	for (i=0;i<ll;i++) {
		result=result+areaconversion*MygetPixel(xpoints[i], ypoints[i],base,negh);
	}
	return result;
}


function LocalBase(xs, ys, widths, heights) {
		base=0;
		numelements=0;
		baseTol=2; // number of pixels used to widening the base evaluation area 
		for (xi=xs-baseTol;xi<=xs+widths+baseTol;xi++) {
			for (yi=ys-baseTol;yi<=ys+heights+baseTol;yi++) {
				if (!Roi.contains(xi, yi)) { 
					base=base+getPixel(xi, yi);
					numelements++;
				}	
			}
		}
		base=base/numelements;
 return base
}


function MygetPixel(x,y,base,negheights) {
	if (negheights) {
		Z=getPixel(x, y)-base;
	} else {
		Z=Math.max(getPixel(x, y)-base, 0);
	}
	return Z
}
