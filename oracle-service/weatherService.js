require('dotenv').config();
const { ethers } = require('ethers');
const axios = require('axios');

// OpenWeatherMap API configuration
const OPENWEATHER_API_KEY = process.env.OPENWEATHER_API_KEY;
const OPENWEATHER_BASE_URL = 'https://api.openweathermap.org/data/2.5/weather';

// Blockchain configuration
const RPC_URL = process.env.RPC_URL || 'http://localhost:8545';
const PRIVATE_KEY = process.env.ORACLE_PRIVATE_KEY;
const ORACLE_ADDRESS = process.env.ORACLE_CONTRACT_ADDRESS;

// ABI for the OpenWeatherOracle contract (only the functions we need)
const ORACLE_ABI = [
    "function addLocation(string name, int256 latitude, int256 longitude, string country) external",
    "function updateWeather(string locationName, int256 temperature, uint256 humidity, uint256 pressure, uint256 windSpeed, uint256 windDeg, uint256 cloudiness, uint256 rainfall, string weatherMain, string weatherDesc) external",
    "function getLocation(string locationName) external view returns (tuple(string name, int256 latitude, int256 longitude, string country))"
];

class WeatherOracleService {
    constructor() {
        this.provider = new ethers.JsonRpcProvider(RPC_URL);
        this.wallet = new ethers.Wallet(PRIVATE_KEY, this.provider);
        this.oracle = new ethers.Contract(ORACLE_ADDRESS, ORACLE_ABI, this.wallet);
        
        // List of cities to monitor
        this.cities = [
            { name: "San Francisco", country: "US" },
            { name: "Miami", country: "US" },
            { name: "New York", country: "US" },
            { name: "Tokyo", country: "JP" },
            { name: "London", country: "GB" }
        ];
    }

    async initialize() {
        console.log('Initializing Weather Oracle Service...');
        
        // Register all cities
        for (const city of this.cities) {
            try {
                // Get city coordinates from OpenWeatherMap
                const geoData = await this.getCityCoordinates(city.name, city.country);
                if (geoData) {
                    // Convert coordinates to the format expected by the contract
                    const lat = Math.round(geoData.lat * 1e6);
                    const lon = Math.round(geoData.lon * 1e6);
                    
                    // Add location to the oracle
                    await this.oracle.addLocation(
                        city.name,
                        lat,
                        lon,
                        city.country
                    );
                    console.log(`Registered ${city.name}, ${city.country}`);
                }
            } catch (error) {
                if (!error.message.includes("Location already registered")) {
                    console.error(`Error registering ${city.name}:`, error);
                }
            }
        }
    }

    async getCityCoordinates(city, country) {
        try {
            const response = await axios.get(
                `http://api.openweathermap.org/geo/1.0/direct?q=${city},${country}&limit=1&appid=${OPENWEATHER_API_KEY}`
            );
            if (response.data && response.data.length > 0) {
                return {
                    lat: response.data[0].lat,
                    lon: response.data[0].lon
                };
            }
        } catch (error) {
            console.error(`Error getting coordinates for ${city}:`, error);
        }
        return null;
    }

    async updateWeatherData() {
        for (const city of this.cities) {
            try {
                // Fetch weather data from OpenWeatherMap
                const response = await axios.get(OPENWEATHER_BASE_URL, {
                    params: {
                        q: `${city.name},${city.country}`,
                        appid: OPENWEATHER_API_KEY,
                        units: 'metric'
                    }
                });

                const data = response.data;
                
                // Convert the data to the format expected by our contract
                const weatherData = {
                    temperature: Math.round(data.main.temp * 10), // Convert to tenths of a degree
                    humidity: data.main.humidity,
                    pressure: data.main.pressure,
                    windSpeed: Math.round(data.wind.speed * 10), // Convert to tenths of m/s
                    windDeg: data.wind.deg,
                    cloudiness: data.clouds.all,
                    rainfall: Math.round((data.rain?.['3h'] || 0) * 10), // Convert to tenths of mm
                    weatherMain: data.weather[0].main,
                    weatherDesc: data.weather[0].description
                };

                // Update the oracle
                await this.oracle.updateWeather(
                    city.name,
                    weatherData.temperature,
                    weatherData.humidity,
                    weatherData.pressure,
                    weatherData.windSpeed,
                    weatherData.windDeg,
                    weatherData.cloudiness,
                    weatherData.rainfall,
                    weatherData.weatherMain,
                    weatherData.weatherDesc
                );

                console.log(`Updated weather data for ${city.name}`);
                console.log('Temperature:', weatherData.temperature/10, '°C');
                console.log('Weather:', weatherData.weatherDesc);
                console.log('---');

            } catch (error) {
                console.error(`Error updating weather for ${city.name}:`, error);
            }
        }
    }

    async start() {
        await this.initialize();
        
        // Update weather data immediately
        await this.updateWeatherData();
        
        // Then update every 5 minutes
        setInterval(async () => {
            await this.updateWeatherData();
        }, 5 * 60 * 1000);
    }
}

// Start the service
const service = new WeatherOracleService();
service.start().catch(console.error); 