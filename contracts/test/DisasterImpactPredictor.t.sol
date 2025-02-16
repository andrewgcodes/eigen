// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Test.sol";
import {DisasterImpactPredictor} from "../src/DisasterImpactPredictor.sol";
import {MockWeatherOracle} from "../src/MockWeatherOracle.sol";
import {IDisasterInsuranceServiceManager} from "../src/IDisasterInsuranceServiceManager.sol";

contract DisasterImpactPredictorTest is Test {
    DisasterImpactPredictor public predictor;
    MockWeatherOracle public weatherOracle;

    function setUp() public {
        weatherOracle = new MockWeatherOracle();
        predictor = new DisasterImpactPredictor(address(weatherOracle));

        // Initialize weather data for San Francisco
        weatherOracle.updateWeatherData(
            "San Francisco",
            185,    // 18.5°C
            25,     // 25 km/h wind
            20,     // 2.0mm rainfall
            75,     // 75% humidity
            1013    // 1013 hPa pressure
        );

        // Initialize weather data for Miami
        weatherOracle.updateWeatherData(
            "Miami",
            320,    // 32.0°C
            120,    // 120 km/h wind
            150,    // 15.0mm rainfall
            85,     // 85% humidity
            980     // 980 hPa pressure
        );
    }

    function test_PredictEarthquakeImpact() public {
        MockWeatherOracle.WeatherData memory weather = weatherOracle.getLatestWeatherData("San Francisco");
        
        DisasterImpactPredictor.ImpactPrediction memory prediction = predictor.predictImpact(
            "San Francisco",
            IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE,
            70, // 7.0 magnitude
            weather
        );

        assertTrue(prediction.estimatedDamageUSD > 0);
        assertTrue(prediction.affectedAreaKM2 > 0);
        assertTrue(prediction.populationAffected > 0);
        assertTrue(prediction.infrastructureRisk > 80); // High risk for strong earthquake
        assertTrue(prediction.economicDisruption > 0);
        assertTrue(prediction.confidence > 0);
        
        console2.log("Earthquake Impact Prediction:");
        console2.log("Estimated Damage (USD):", prediction.estimatedDamageUSD);
        console2.log("Affected Area (km2):", prediction.affectedAreaKM2);
        console2.log("Population Affected:", prediction.populationAffected);
        console2.log("Infrastructure Risk:", prediction.infrastructureRisk);
        console2.log("Economic Disruption (days):", prediction.economicDisruption);
        console2.log("Affected Facilities:", prediction.criticalFacilities.length);
        console2.log("Confidence Score:", prediction.confidence);
    }

    function test_PredictHurricaneImpact() public {
        MockWeatherOracle.WeatherData memory weather = weatherOracle.getLatestWeatherData("Miami");
        
        DisasterImpactPredictor.ImpactPrediction memory prediction = predictor.predictImpact(
            "Miami",
            IDisasterInsuranceServiceManager.DisasterType.HURRICANE,
            150, // Category 4-5 hurricane
            weather
        );

        assertTrue(prediction.estimatedDamageUSD > 0);
        assertTrue(prediction.affectedAreaKM2 > 0);
        assertTrue(prediction.populationAffected > 0);
        assertTrue(prediction.infrastructureRisk > 70);
        assertTrue(prediction.economicDisruption > 0);
        assertTrue(prediction.confidence > 80); // High confidence due to weather conditions
        
        console2.log("Hurricane Impact Prediction:");
        console2.log("Estimated Damage (USD):", prediction.estimatedDamageUSD);
        console2.log("Affected Area (km2):", prediction.affectedAreaKM2);
        console2.log("Population Affected:", prediction.populationAffected);
        console2.log("Infrastructure Risk:", prediction.infrastructureRisk);
        console2.log("Economic Disruption (days):", prediction.economicDisruption);
        console2.log("Affected Facilities:", prediction.criticalFacilities.length);
        console2.log("Confidence Score:", prediction.confidence);
    }

    function test_LocationParameters() public {
        DisasterImpactPredictor.ModelParameters memory sfParams = predictor.getLocationParameters("San Francisco");
        
        assertEq(sfParams.populationDensity, 7272);
        assertEq(sfParams.buildingDensity, 2000);
        assertEq(sfParams.averagePropertyValue, 150000000);
        assertEq(sfParams.infrastructureScore, 85);
        assertEq(sfParams.keyInfrastructure.length, 4);
    }

    function test_HistoricalPredictions() public {
        // Make multiple predictions
        MockWeatherOracle.WeatherData memory weather = weatherOracle.getLatestWeatherData("San Francisco");
        
        // Predict for different severities
        predictor.predictImpact(
            "San Francisco",
            IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE,
            50, // 5.0 magnitude
            weather
        );

        predictor.predictImpact(
            "San Francisco",
            IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE,
            70, // 7.0 magnitude
            weather
        );

        DisasterImpactPredictor.ImpactPrediction[] memory history = predictor.getHistoricalPredictions("San Francisco");
        assertEq(history.length, 2);
        assertTrue(history[1].estimatedDamageUSD > history[0].estimatedDamageUSD);
    }

    function test_SeverityScaling() public {
        MockWeatherOracle.WeatherData memory weather = weatherOracle.getLatestWeatherData("San Francisco");
        
        // Test with low severity
        DisasterImpactPredictor.ImpactPrediction memory lowImpact = predictor.predictImpact(
            "San Francisco",
            IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE,
            30, // 3.0 magnitude
            weather
        );

        // Test with high severity
        DisasterImpactPredictor.ImpactPrediction memory highImpact = predictor.predictImpact(
            "San Francisco",
            IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE,
            80, // 8.0 magnitude
            weather
        );

        assertTrue(highImpact.estimatedDamageUSD > lowImpact.estimatedDamageUSD);
        assertTrue(highImpact.affectedAreaKM2 > lowImpact.affectedAreaKM2);
        assertTrue(highImpact.populationAffected > lowImpact.populationAffected);
        assertTrue(highImpact.infrastructureRisk > lowImpact.infrastructureRisk);
        assertTrue(highImpact.economicDisruption > lowImpact.economicDisruption);
        assertTrue(highImpact.criticalFacilities.length > lowImpact.criticalFacilities.length);
    }
} 