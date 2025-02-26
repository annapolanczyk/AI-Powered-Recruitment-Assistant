/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-26-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class DataConverter {
    public static String convertSkillsToString(Object skillsObj) {
        if (!(skillsObj instanceof List<Object>)) {
            return skillsObj instanceof String ? (String)skillsObj : '';
        }
        
        List<String> skillsStringList = new List<String>();
        for(Object skill : (List<Object>)skillsObj) {
            skillsStringList.add(String.valueOf(skill));
        }
        return String.join(skillsStringList, ', ');
    }
    
    public static Decimal toDecimal(Object value) {
        if (value instanceof Decimal) {
            return (Decimal)value;
        }
        if (value instanceof Integer) {
            return (Integer)value;
        }
        if (value instanceof String) {
            try { 
                return Decimal.valueOf((String)value); 
            } catch(Exception e) { 
                return 0; 
            }
        }
        return 0;
    }
} 