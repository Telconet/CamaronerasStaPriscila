/*  
 *  ------ Waspmote Pro Code Example -------- 
 *  
 *  Explanation: This is the basic Code for Waspmote Pro
 *  
 *  Copyright (C) 2013 Libelium Comunicaciones Distribuidas S.L. 
 *  http://www.libelium.com 
 *  
 *  This program is free software: you can redistribute it and/or modify  
 *  it under the terms of the GNU General Public License as published by  
 *  the Free Software Foundation, either version 3 of the License, or  
 *  (at your option) any later version.  
 *   
 *  This program is distributed in the hope that it will be useful,  
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of  
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the  
 *  GNU General Public License for more details.  
 *   
 *  You should have received a copy of the GNU General Public License  
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.  
 */

// Put your libraries here (#include ...)
#include <WaspFrame.h>
#include <WaspFrameConstants.h>
#include <WaspSensorSW.h>
#include <WaspSX1272.h>
#include <stdint.h>
#include <string.h>
#include <WaspUtils.h>



// SOCKET
///////////////////////////////////////
uint8_t socket=SOCKET0;
///////////////////////////////////////

//LoRA
uint8_t direccion_tx = 2;      //direccion de transmision
char *waspmote_id = "SPRISC_1";
int status;

#define MODO_TRANSMISION 5
#define DIRECCION_NODO 15      //Nuestra direccion
#define REINTENTOS_TRANSMISION 3

//Referente al sensor pH, DO y Cond
#define DIRECCION_CAL_PH_10   1024
#define DIRECCION_CAL_PH_7    1028
#define DIRECCION_CAL_PH_4    1032
#define DIRECCION_CAL_TEMP    1036
#define CAL_DO_0              1040
#define CAL_DO_100            1044
#define CAL_COND_RES_1        1048      //Resistencia sensor conductividad punto calibracion 1
#define CAL_COND_RES_2        1052      //Resistencia sensor cpunto calibracion 2
#define CAL_COND_US_CM_1      1056      //Conductividad (uS/cm) calibracion 1
#define CAL_COND_US_CM_2      1060      //Conductividad (uS/cm) calibracion 2

//Referente al numero de muestras a tomar
#define NUMERO_MUESTRAS 30.0f;
#define NUMERO_ITERACIONES 30

//Sondas
pHClass pHSensor;
pt1000Class temperatureSensor;
DOClass DOSensor;
conductivityClass ConductivitySensor;


//variables a medir
float nivel_ph = 0.0f;
float ph = 0.0f;
float temperatura = 0.0f;
float temperaturaAc = 0.0f;
float doxygenAc = 0.0f;
float doxygen = 0.0f;
float res_cond = 0.0f;
float conduc_mS_cm = 0.0f;



/*Lee un float desde la memoria EEPROM. El valor es leído y 
 *devuelto en formato little-endian.
 */
void leerFloatEEPROM(float *valor, int direccionInicial){

  //Valor es el bloque de memoria donde devolveremos el valor leído
  uint8_t *valor_int_cast = (uint8_t *)valor;

  int i = 0;
  for(i = 0; i < 4 ; i++){
    uint8_t valorLeido = Utils.readEEPROM(direccionInicial + i);
    *(valor_int_cast+i) = valorLeido;
  }
}




void setup() {

  RTC.ON();  
  USB.ON();

  //Leemos la memoria EEPROM para obtener la información de calibración del sensor de pH
  float ph4 = 0.0f;
  float ph7 = 0.0f;
  float ph10 = 0.0f;
  float caltemp = 0.0f;

  //Calibraciones sensor pH
  leerFloatEEPROM(&ph4, DIRECCION_CAL_PH_4);
  leerFloatEEPROM(&ph7, DIRECCION_CAL_PH_7);
  leerFloatEEPROM(&ph10, DIRECCION_CAL_PH_10);
  leerFloatEEPROM(&caltemp, DIRECCION_CAL_TEMP);

  USB.println(ph4);
  USB.println(ph7);
  USB.println(ph10);
  USB.println(caltemp);


  pHSensor.setCalibrationPoints(ph10, ph7, ph4, caltemp);

  //Ahora el sensor de oxigeno disuelto
  float calib_do_100 = 0.0f;
  float calib_do_0 = 0.0f;

  leerFloatEEPROM(&calib_do_100, CAL_DO_100);
  leerFloatEEPROM(&calib_do_0, CAL_DO_0);

  USB.println(calib_do_100);
  USB.println(calib_do_0);

  DOSensor.setCalibrationPoints(calib_do_100, calib_do_0);

  //Ahora leemos el sensor de conductividad
  float res_1 =0.0f;
  float res_2 = 0.0f;
  float cond_1 = 0.0f;
  float cond_2 = 0.0f;

  leerFloatEEPROM(&res_1, CAL_COND_RES_1);
  leerFloatEEPROM(&res_2, CAL_COND_RES_2);
  leerFloatEEPROM(&cond_1, CAL_COND_US_CM_1);
  leerFloatEEPROM(&cond_2, CAL_COND_US_CM_2);

  USB.println(res_1);
  USB.println(cond_1);
  USB.println(res_2);
  USB.println(cond_2);

  ConductivitySensor.setCalibrationPoints(cond_1, res_1, cond_2, res_2);
  
}


void loop() {

  Utils.setLED(LED0, LED_ON);
  delay(1000);
  Utils.setLED(LED0, LED_OFF);

  int status = 0;


  if( intFlag & RTC_INT )
  {
    interruptRTC();
  }


  SensorSW.ON();
  delay(5000);

  USB.println("Leyendo...");


  float nivel_ph = 0.0f;
  float temperatura = 0.0f;
  float ph = 0.0f;
  float conductividad = 0.0f;

  //pH & temperatura
  nivel_ph = pHSensor.readpH();
  temperatura = temperatureSensor.readTemperature();
  ph = pHSensor.pHConversion(nivel_ph, temperatura);

  //DO
  float doxygen = DOSensor.readDO();
  doxygen = DOSensor.DOConversion(doxygen);
  
  //Conductividad
  res_cond = ConductivitySensor.readConductivity();
  conduc_mS_cm = ConductivitySensor.conductivityConversion(res_cond);

  USB.print(F("Oxigeno disuelto: "));
  USB.println(doxygen);
  USB.print(F("Temperatura: "));
  USB.println(temperatura);
  USB.print(F("pH: "));
  USB.println(ph);
  USB.print(F("Conductividad (mS/cm): "));
  USB.println(conduc_mS_cm);

  USB.println(status);
  SensorSW.OFF();

  delay(2000);

  //Apagamos tarjeta SW

  //Encendemos LoRA 900
 
  
  //Creamos el frame
  frame.createFrame(ASCII); 
  frame.setID(waspmote_id);

  // set frame fields 
  frame.addSensor(SENSOR_BAT, PWR.getBatteryLevel() );
  frame.addSensor(SENSOR_PH, ph);
  frame.addSensor(SENSOR_TCA, temperatura); 
  frame.addSensor(SENSOR_DO, doxygen);    
  frame.addSensor(SENSOR_COND, conduc_mS_cm);  
  frame.showFrame();
    
  
  sx1272.ON();
  delay(2000);
  configurarLoRA();
  delay(1000);
  
  status = sx1272.sendPacketTimeoutACKRetries( direccion_tx, frame.buffer, frame.length);
  
  
  // 2.2. Check sending status
  if( status == 0 ) 
  {
    USB.println(F("--> Envio paquete OK"));     
  }
  else 
  {
    USB.println(F("--> Error al enviar paquete"));  
    USB.print(F("state: "));
    USB.println(status, DEC);
  } 
  
  sx1272.ON();

  
 

  
  USB.println(F("***************************"));

  USB.println(F("Nos vamos a dormir..."));
  PWR.deepSleep("00:00:05:00", RTC_OFFSET, RTC_ALM1_MODE2, SENS_OFF);   //duerme 20 minuto //ALL_OFF  //ALL_OFF
  USB.println("Nos levantamos");

  delay(1000);
}



//Deep Sleep
void interruptRTC()
{
  USB.println(F("---------------------"));
  USB.println(F("Interrupt de RTC capturado"));
  USB.println(F("---------------------"));
  intFlag &= ~(RTC_INT);  
  delay(5000);
}


void configurarLoRA(){

  // Select frequency channel
  status = sx1272.setChannel(CH_12_900);
  USB.print(F("Configurando canal -> status: ")); 
  USB.println(status);

  // Header encendido o apagado
  status = sx1272.setHeaderON();
  USB.print(F("Configurando header ON -> status: ")); 
  USB.println(status); 

  //Modo de transmision 1 a 10 (1 menos BW y más rango, 10 más BW y menos rango)
  status = sx1272.setMode(MODO_TRANSMISION);  
  USB.print(F("Modo transmision: ")); 
  USB.print(MODO_TRANSMISION);
  USB.print(F(" -> status: "));
  USB.println(status);  

  // Habilitar CRC
  status = sx1272.setCRC_ON();
  USB.print(F("Encendiendo CRC -> status: ")); 
  USB.println(status);  

  // Select output power (Max, High or Low)
  status = sx1272.setPower('H');
  USB.print(F("Potencua H -> status: ")); 
  USB.println(status); 

  // Select the node address value: from 2 to 255
  status = sx1272.setNodeAddress(DIRECCION_NODO);
  USB.print(F("Direccion NODO: ")); 
  USB.print(DIRECCION_NODO);
  USB.print(F(" -> status: "));
  USB.println(status); 

  // Reintentos (0 a 5)
  status = sx1272.setRetries(REINTENTOS_TRANSMISION);
  USB.print(F("Direccion NODO: ")); 
  USB.print(REINTENTOS_TRANSMISION);
  USB.print(F(" -> status: "));
  USB.println(status); 

  USB.print(F("LoRA confugigurado"));

  delay(1000);  
  

}



/*SensorSW.ON(); 
 delay(1000);
 
 ph = 0.0f;
 temperatura = 0.0f;
 doxygen = 0.0f;
 doxygenAc = 0.0f;
 temperaturaAc = 0.0f;
 nivel_ph = 0.0f;
 
 
 //pH & temperatura
 nivel_ph = pHSensor.readpH();
 temperatura = temperatureSensor.readTemperature();
 ph = pHSensor.pHConversion(nivel_ph, temperatura);
 
 //DO
 doxygen = DOSensor.readDO();
 doxygen = DOSensor.DOConversion(doxygen);
 
 int i = 0;
 for(i = 0; i < 5; i++){
 
 //pH & temperatura
 nivel_ph = pHSensor.readpH();
 temperatura = temperatureSensor.readTemperature();
 temperaturaAc = temperaturaAc + temperatura;
 ph += pHSensor.pHConversion(nivel_ph, temperatura);
 
 //DO
 doxygen = DOSensor.readDO();
 doxygen = DOSensor.DOConversion(doxygen);
 
 doxygenAc =  doxygenAc + doxygen;
 
 }
 
 ph = ph / 5.0f;
 temperaturaAc = temperaturaAc / 5.0f;
 doxygenAc = doxygenAc / 5.0f;
 
 USB.println(ph);
 USB.println(temperaturaAc);
 USB.println(doxygenAc);
 
 USB.println(" ");
 
 //Apagamos tarjeta SW
 SensorSW.OFF();*/



