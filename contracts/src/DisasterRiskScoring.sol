// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IDisasterInsuranceServiceManager} from "./IDisasterInsuranceServiceManager.sol";
import {MockWeatherOracle} from "./MockWeatherOracle.sol";

contract DisasterRiskScoring {
    struct RiskScore {
        uint256 baseScore;           // 0-100
        uint256 weatherMultiplier;   // in basis points (100 = 1x)
        uint256 seasonalMultiplier;  // in basis points
        uint256 historicalMultiplier;// in basis points
        string[] riskFactors;
        uint256 timestamp;
    }

    struct HistoricalEvent {
        IDisasterInsuranceServiceManager.DisasterType disasterType;
        uint256 severity;
        uint256 timestamp;
        uint256 damageAmount;
    }

    MockWeatherOracle public weatherOracle;
    mapping(bytes32 => RiskScore) public locationRiskScores;
    mapping(bytes32 => HistoricalEvent[]) public locationHistory;
    
    // Seasonal risk factors (by month, 1-12)
    mapping(uint256 => mapping(IDisasterInsuranceServiceManager.DisasterType => uint256)) public seasonalRiskFactors;

    event RiskScoreUpdated(
        string location,
        uint256 baseScore,
        uint256 finalScore,
        uint256 timestamp
    );

    constructor(address _weatherOracle) {
        weatherOracle = MockWeatherOracle(_weatherOracle);
        
        // Initialize seasonal risk factors
        // Earthquake risk is relatively constant
        for (uint256 i = 1; i <= 12; i++) {
            seasonalRiskFactors[i][IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE] = 100;
        }
        
        // Hurricane season (June-November has higher risk)
        seasonalRiskFactors[6][IDisasterInsuranceServiceManager.DisasterType.HURRICANE] = 150;
        seasonalRiskFactors[7][IDisasterInsuranceServiceManager.DisasterType.HURRICANE] = 200;
        seasonalRiskFactors[8][IDisasterInsuranceServiceManager.DisasterType.HURRICANE] = 250;
        seasonalRiskFactors[9][IDisasterInsuranceServiceManager.DisasterType.HURRICANE] = 250;
        seasonalRiskFactors[10][IDisasterInsuranceServiceManager.DisasterType.HURRICANE] = 200;
        seasonalRiskFactors[11][IDisasterInsuranceServiceManager.DisasterType.HURRICANE] = 150;
        
        // Flood risk varies by season
        seasonalRiskFactors[3][IDisasterInsuranceServiceManager.DisasterType.FLOOD] = 150; // Spring
        seasonalRiskFactors[4][IDisasterInsuranceServiceManager.DisasterType.FLOOD] = 200;
        seasonalRiskFactors[5][IDisasterInsuranceServiceManager.DisasterType.FLOOD] = 150;
        seasonalRiskFactors[9][IDisasterInsuranceServiceManager.DisasterType.FLOOD] = 150; // Fall
        seasonalRiskFactors[10][IDisasterInsuranceServiceManager.DisasterType.FLOOD] = 200;
        seasonalRiskFactors[11][IDisasterInsuranceServiceManager.DisasterType.FLOOD] = 150;
    }

    function calculateRiskScore(
        string memory location,
        IDisasterInsuranceServiceManager.DisasterType disasterType
    ) external returns (uint256) {
        bytes32 locationHash = keccak256(bytes(location));
        
        // Get current weather data
        MockWeatherOracle.WeatherData memory weather = weatherOracle.getLatestWeatherData(location);
        
        // Calculate weather multiplier based on current conditions
        uint256 weatherMultiplier = 100; // base 1x
        if (disasterType == IDisasterInsuranceServiceManager.DisasterType.HURRICANE) {
            if (weather.windSpeed > 100) weatherMultiplier += 50;
            if (weather.pressure < 990) weatherMultiplier += 50;
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.FLOOD) {
            if (weather.rainfall > 100) weatherMultiplier += 50;
            if (weather.humidity > 85) weatherMultiplier += 25;
        }
        
        // Get seasonal multiplier
        uint256 currentMonth = (block.timestamp / 30 days) % 12 + 1;
        uint256 seasonalMultiplier = seasonalRiskFactors[currentMonth][disasterType];
        
        // Calculate historical multiplier
        uint256 historicalMultiplier = 100;
        HistoricalEvent[] storage history = locationHistory[locationHash];
        if (history.length > 0) {
            uint256 recentEvents = 0;
            for (uint256 i = 0; i < history.length; i++) {
                if (
                    history[i].disasterType == disasterType &&
                    block.timestamp - history[i].timestamp < 365 days
                ) {
                    recentEvents++;
                }
            }
            historicalMultiplier += recentEvents * 25;
        }
        
        // Calculate base score using location data
        MockWeatherOracle.LocationData memory loc = weatherOracle.getLocationData(location);
        uint256 baseScore = calculateBaseScore(loc, disasterType);
        
        // Combine all factors
        uint256 finalScore = (baseScore * weatherMultiplier * seasonalMultiplier * historicalMultiplier) / 1000000;
        
        // Store the risk score
        string[] memory factors = new string[](3);
        factors[0] = "Weather conditions";
        factors[1] = "Seasonal patterns";
        factors[2] = "Historical events";
        
        locationRiskScores[locationHash] = RiskScore({
            baseScore: baseScore,
            weatherMultiplier: weatherMultiplier,
            seasonalMultiplier: seasonalMultiplier,
            historicalMultiplier: historicalMultiplier,
            riskFactors: factors,
            timestamp: block.timestamp
        });
        
        emit RiskScoreUpdated(location, baseScore, finalScore, block.timestamp);
        
        return finalScore;
    }
    
    function recordHistoricalEvent(
        string memory location,
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        uint256 severity,
        uint256 damageAmount
    ) external {
        bytes32 locationHash = keccak256(bytes(location));
        
        locationHistory[locationHash].push(HistoricalEvent({
            disasterType: disasterType,
            severity: severity,
            timestamp: block.timestamp,
            damageAmount: damageAmount
        }));
    }
    
    function calculateBaseScore(
        MockWeatherOracle.LocationData memory location,
        IDisasterInsuranceServiceManager.DisasterType disasterType
    ) internal pure returns (uint256) {
        if (disasterType == IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE) {
            // Higher risk for locations near fault lines (simplified for demo)
            if (
                location.latitude > 35000000 && location.latitude < 40000000 &&
                location.longitude > -125000000 && location.longitude < -120000000
            ) {
                return 80; // High risk zone (e.g., San Francisco)
            }
            return 30;
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.HURRICANE) {
            // Higher risk for coastal locations at certain latitudes
            if (
                location.latitude > 20000000 && location.latitude < 35000000 &&
                location.elevation < 10
            ) {
                return 85; // High risk zone (e.g., Miami)
            }
            return 25;
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.FLOOD) {
            // Higher risk for low elevation areas
            if (location.elevation < 5) {
                return 75;
            } else if (location.elevation < 20) {
                return 50;
            }
            return 20;
        }
        return 50; // Default score
    }
    
    function getLocationRiskScore(string memory location)
        external
        view
        returns (RiskScore memory)
    {
        bytes32 locationHash = keccak256(bytes(location));
        require(locationRiskScores[locationHash].timestamp > 0, "No risk score available");
        return locationRiskScores[locationHash];
    }
    
    function getLocationHistory(string memory location)
        external
        view
        returns (HistoricalEvent[] memory)
    {
        bytes32 locationHash = keccak256(bytes(location));
        return locationHistory[locationHash];
    }
} 